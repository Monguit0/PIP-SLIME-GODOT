class_name Slime
extends CharacterBody2D
## Slimes del Reino, con la lógica del juego web:
## - verde (updateGreen): patrulla su superficie a saltitos, 1 de vida.
## - rojo (updateRed): te persigue por toda la zona y salta para alcanzarte, 2 de vida.
## Hoja HD: assets/sprites/slimes.png, 13 cuadros de 32x26 por fila (verde, rojo, tóxico, hielo),
## dibujada a la mitad (16x13 en el mundo). Cuadros: 0-7 respirar (el 6 es el parpadeo, que va al azar),
## 8 agachado (antes de saltar y al caer), 9 boca abierta (subiendo en el salto), 10 golpe, 11-12 reventar.

signal killed

const GRAV := 900.0
const FW := 32
const FH := 26
const SHEET := preload("res://assets/sprites/slimes.png")
const ROWS := {"green": 0, "red": 1, "toxic": 2, "ice": 3}
const HP := {"green": 1, "red": 2, "toxic": 1, "ice": 2}
const COL := {"green": Pal.G, "red": Pal.R, "toxic": Pal.P, "ice": Pal.B}  # color de la baba
const Pix := preload("res://scripts/pix.gd")

var kind := "green"
var zone := 0
var min_x := 0.0
var max_x := 99999.0

var hp := 1
var dir := 1.0
var hop_t := 0.0
var jump_t := 0.0
var stun := 0.0
var knock := 0.0
var flash := 0.0
var spawn := 0.0
var dead := false
var dead_t := 0.0
var squash := Vector2.ONE
var phase := 0.0
var face := -1.0
var sprite: Sprite2D
var hurtbox: Area2D
var target: Area2D  # blanco para las flechas: más alto que el slime, así no le pasan por arriba
var hero: Player
var game  # main.gd
var ven_t := 0.0  # veneno del Cazador: le saca 1 cada 0,7 s mientras dura
var ven_k := 0.0
var prep := 0.0     # se agacha un instante antes de saltar
var jump_up := false
var land_t := 0.0
var blink_t := 0.0
var blink := 0.0


func _ready() -> void:
	add_to_group("enemigos")
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	floor_snap_length = 2.0
	hp = HP.get(kind, 1)
	dir = -1.0 if randf() < 0.5 else 1.0
	hop_t = 1.0 + randf() * 3.0
	jump_t = 0.6 + randf()
	spawn = 0.5 + randf() * 0.4
	phase = randf() * 8.0
	blink_t = randf_range(1.0, 4.0)
	hero = get_tree().get_first_node_in_group("heroe") as Player
	game = get_tree().get_first_node_in_group("juego")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)

	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.region_enabled = true
	sprite.centered = true
	sprite.offset = Vector2(0, -FH / 2.0 + 1)
	add_child(sprite)

	# zona que lastima al héroe y que reciben las flechas
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 0
	hurtbox.set_collision_layer_value(4, true)
	hurtbox.collision_mask = 0
	hurtbox.set_collision_mask_value(3, true)
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(10, 7)
	hs.shape = hr
	hs.position = Vector2(0, -3.5)
	hurtbox.add_child(hs)
	add_child(hurtbox)

	# las flechas salen a la altura del arco (unos 11 px del piso) y el slime mide 7:
	# el blanco para flechas es más alto (14 px) para que un tiro recto siempre conecte
	target = Area2D.new()
	target.collision_layer = 0
	target.set_collision_layer_value(5, true)
	target.collision_mask = 0
	target.monitoring = false
	var ts := CollisionShape2D.new()
	var tr := RectangleShape2D.new()
	tr.size = Vector2(12, 14)
	ts.shape = tr
	ts.position = Vector2(0, -7)
	target.add_child(ts)
	add_child(target)
	_set_frame(0)
	sprite.scale = Vector2.ZERO


func _physics_process(dt: float) -> void:
	flash -= dt
	if dead:
		dead_t += dt
		_set_frame(11 if dead_t < 0.07 else 12)
		squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
		sprite.scale = squash * 0.5
		sprite.material = Fx.silhouette(Color.WHITE) if flash > 0.0 else null
		sprite.modulate = Color.WHITE if flash > 0.0 else Color(1, 1, 1, 1.0 - clampf((dead_t - 0.2) / 0.3, 0.0, 1.0))
		if dead_t > 0.5:
			queue_free()
		return
	if spawn > 0.0:  # aparece inflándose y no lastima
		spawn -= dt
		var k := clampf(1.0 - spawn / 0.5, 0.0, 1.0)
		sprite.scale = Vector2(0.5, 0.5) * Vector2(k, k)
		sprite.modulate.a = k
		return

	if ven_t > 0.0:
		_venom_tick(dt)
		if dead:
			return
	if kind == "red":
		_update_red(dt)
	else:
		_update_green(dt)
	if knock != 0.0:
		velocity.x += knock
		knock *= maxf(0.0, 1.0 - 6.0 * dt)
		if absf(knock) < 6.0:
			knock = 0.0
	var fall := velocity.y
	var was_floor := is_on_floor()
	move_and_slide()
	if knock != 0.0:
		velocity.x -= knock
	if is_on_floor() and not was_floor and fall > 120.0:
		squash = Vector2(1.4, 0.6)
		land_t = 0.1
		Fx.dust(get_parent(), global_position, 2, 14.0, 2.0, 1.1)
	if position.x < min_x:
		position.x = min_x
		dir = 1.0
		velocity.x = absf(velocity.x)
		knock = 0.0
	elif position.x > max_x:
		position.x = max_x
		dir = -1.0
		velocity.x = -absf(velocity.x)
		knock = 0.0

	_touch_hero()
	_animate(dt)


func _update_green(dt: float) -> void:
	var speed := 18.0 + zone * 4.0
	if stun > 0.0:
		stun -= dt
		velocity.x = 0.0
		prep = 0.0
	else:
		velocity.x = dir * speed * (0.3 if prep > 0.0 else 1.0)
		face = dir
	hop_t -= dt
	if hop_t <= 0.0 and is_on_floor() and prep <= 0.0 and stun <= 0.0:
		prep = 0.13  # se agacha antes del saltito
		hop_t = 1.6 + randf() * 2.6
		squash = Vector2(1.3, 0.72)
	if prep > 0.0:
		prep -= dt
		if prep <= 0.0 and is_on_floor():
			velocity.y = -150.0
			squash = Vector2(0.7, 1.4)
			Fx.dust(get_parent(), global_position, 2, 16.0, 3.0, 1.2)
	velocity.y = minf(velocity.y + GRAV * dt, 280.0)


func _update_red(dt: float) -> void:
	var dx := 999.0
	var above := false
	if hero and not hero.dead:
		dx = hero.global_position.x - global_position.x
		above = hero.global_position.y < global_position.y - 14.0
	var speed := 34.0 + zone * 5.0
	if stun > 0.0:
		stun -= dt
		prep = 0.0
		if is_on_floor():
			velocity.x *= maxf(0.0, 1.0 - 8.0 * dt)
	elif is_on_floor() and prep > 0.0:  # agachado, juntando fuerza
		velocity.x *= maxf(0.0, 1.0 - 12.0 * dt)
		prep -= dt
		if prep <= 0.0:
			velocity.y = -285.0 if jump_up else -175.0
			velocity.x = (signf(dx) if dx != 0.0 else face) * speed * 1.5
			squash = Vector2(0.65, 1.45)
			Fx.dust(get_parent(), global_position, 3, 22.0, 3.0, 1.4)
	elif is_on_floor():
		var want := 0.0 if absf(dx) > 220.0 else signf(dx) * speed
		velocity.x += signf(want - velocity.x) * minf(absf(want - velocity.x), 320.0 * dt)
		if absf(dx) < 220.0:
			face = signf(dx) if dx != 0.0 else face
		jump_t -= dt
		if jump_t <= 0.0 and absf(dx) < 220.0 and ((above and absf(dx) < 80.0) or absf(dx) < 34.0):
			prep = 0.1
			jump_up = above
			jump_t = 0.8 + randf() * 0.7
			squash = Vector2(1.35, 0.7)
	velocity.y = minf(velocity.y + GRAV * dt, 280.0)


func _touch_hero() -> void:
	for body in hurtbox.get_overlapping_bodies():
		var p := body as Player
		if p == null or p.dead:
			continue
		# pisotón: viene bajando (respecto del slime) y en el cuadro anterior tenía los pies en la mitad
		# de arriba del slime. Es generoso a propósito: la superposición se detecta con un cuadro de
		# atraso y cayendo rápido Pip baja ~4,5 px por cuadro.
		var top := global_position.y - 7.0
		var stomp := p.velocity.y - velocity.y > 0.0 and p.prev_bottom <= top + 6.0
		for fb in p.recent_bottoms:
			if fb <= top + 5.0:
				stomp = true
		if p.stomp_inv > 0.0:
			continue  # recién rebotó en un slime: ni otro pisotón ni daño por un instante
		if stomp:
			p.bounce()
			take_hit(1, 0, "stomp")
		else:
			p.hurt(global_position.x)


## how: "arrow", "stomp", "trap" (lo aplastó algo que cayó) o "poison" (veneno).
func take_hit(dmg: int, from_dir: int, how: String = "arrow") -> void:
	if dead or spawn > 0.0:
		return
	var crit := how != "trap" and how != "poison" and Fx.rand_crit()
	hp -= dmg * 3 if crit else dmg
	if crit:
		Fx.crit(get_parent(), global_position + Vector2(0, -4))
	if hp <= 0:
		_die(how, from_dir, crit)
		return
	flash = 0.12
	stun = 0.4
	var kd := from_dir if from_dir != 0 else (-1 if randf() < 0.5 else 1)
	knock = kd * 110.0
	velocity.y = -120.0
	squash = Vector2(1.8, 0.35) if how == "stomp" else Vector2(1.45, 0.65)
	prep = 0.0
	Snd.play("pisoton" if how == "stomp" else "acierto")
	Fx.hitstop(0.035)
	var col: Color = COL.get(kind, Pal.G)
	Fx.hit(get_parent(), global_position + Vector2(-kd * 3.0, -4), Vector2(0, 1) if how == "stomp" else Vector2(kd, 0), Pal.W)
	Fx.goo(get_parent(), global_position + Vector2(0, -4), 4, col, 70.0, global_position.y)
	Fx.popup(get_parent(), global_position + Vector2(0, -12), "-%d" % dmg, Pal.W)


## Rectángulo del cuerpo (para las trampas que caen).
func hit_rect() -> Rect2:
	return Rect2(global_position.x - 5, global_position.y - 7, 10, 7)


func apply_venom() -> void:
	if dead:
		return
	ven_t = 3.0
	if ven_k <= 0.0:
		ven_k = 0.7


func _venom_tick(dt: float) -> void:
	ven_t -= dt
	ven_k -= dt
	if randf() < 0.3:
		Fx.part(get_parent(), global_position + Vector2(randf_range(-5, 5), -randf_range(1, 6)), Vector2(0, -18), -10.0, 0.45, Pal.L if randf() < 0.5 else Pal.G)
	if ven_k <= 0.0:
		ven_k = 0.7
		hp -= 1
		flash = 0.08
		Snd.play("baba", {"rate": 1.5, "vol": 0.5})
		Fx.popup(get_parent(), global_position + Vector2(0, -12), "-1", Pal.L)
		if hp <= 0:
			_die("poison", 0, false)


func _die(how: String, from_dir: int, crit: bool) -> void:
	dead = true
	dead_t = 0.0
	flash = 0.2 if crit else 0.1
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	target.set_deferred("monitorable", false)
	var cols := [Pal.R, Pal.O, Pal.P] if kind == "red" else [Pal.G, Pal.L, Pal.RAMP_G[0]]
	if how == "stomp":
		squash = Vector2(1.8, 0.35)
		Fx.hitstop(0.055)
		Fx.shake(2.0, 0.14)
	else:
		squash = Vector2(0.6, 1.45)
		position.x += from_dir * 3
		Fx.hitstop(0.04)
		Fx.shake(1.5, 0.1)
	if how != "trap":
		Snd.play("pisoton" if how == "stomp" else "acierto")
	Snd.play("explotar", {"delay": 0.05, "vol": 0.9})
	# revienta: estrella, gotas que vuelan y quedan como manchitas, charco y un anillo de su color
	var col: Color = COL.get(kind, Pal.G)
	var at := global_position + Vector2(0, -4)
	Fx.hit(get_parent(), at, Vector2(0, 1) if how == "stomp" else Vector2(from_dir if from_dir != 0 else 1, -0.2), Pal.W, crit)
	Fx.goo(get_parent(), at, 14 if crit else 9, col, 120.0 if crit else 85.0, global_position.y)
	Fx.burst(get_parent(), at, 10 if crit else 6, cols, 120.0 if crit else 80.0, 50.0, 0.5, 260.0)
	if crit:
		Fx.ring(get_parent(), at, col, 0.0, 16.0, 1.0, 0.3)
	Fx.shock(get_parent(), global_position, Pix.shade(col, 1), 12.0, 0.25)  # salpicón en el piso
	if is_on_floor():
		Fx.splat(get_parent(), global_position, col, 11.0 if how == "stomp" else 8.0)
		if how == "stomp":
			Fx.dust(get_parent(), global_position, 4, 30.0, 3.0, 1.6)
	if game != null:
		game.slime_killed(self, how, crit)
	killed.emit()


func _animate(dt: float) -> void:
	var tt := Time.get_ticks_msec() / 1000.0
	var fps := 12.0 if kind == "red" else 8.0
	var f := int(tt * fps + phase) % 8
	if f == 6:
		f = 5  # el parpadeo no va en cada vuelta: va aparte, cada tanto
	blink_t -= dt
	if blink_t <= 0.0:
		blink_t = randf_range(1.8, 4.5)
		blink = 0.12
	if blink > 0.0:
		blink -= dt
		f = 6
	land_t -= dt
	if stun > 0.0:
		f = 10
	elif prep > 0.0 or land_t > 0.0:
		f = 8   # agachado
	elif not is_on_floor() and velocity.y < -20.0:
		f = 9   # subiendo con la boca abierta
	_set_frame(f)
	sprite.flip_h = face < 0.0
	var rest := Vector2(1.2, 0.82) if prep > 0.0 else Vector2.ONE
	squash = squash.lerp(rest, minf(1.0, dt * 10.0))
	sprite.scale = squash * 0.5
	var white := flash > 0.0
	sprite.material = Fx.silhouette(Color.WHITE) if white else null
	sprite.modulate = Color.WHITE if white else (Color(0.75, 1.25, 0.6) if ven_t > 0.0 else Color.WHITE)


func _set_frame(i: int) -> void:
	sprite.region_rect = Rect2(i * FW, ROWS.get(kind, 0) * FH, FW, FH)
