extends CharacterBody2D
## Esqueletos del castillo (del modo villano del juego web, MOB.skarch / MOB.skaxe):
## - arquero ("skarch"): guarda distancia (se aleja si te acercás a menos de 56 px, se arrima si
##   estás a más de 120) y te tira flechas rectas cada 1,6-2,3 s. 3 de vida.
## - hachero ("skaxe"): te persigue y, a menos de 24 px, levanta el hacha (0,38 s de aviso) y
##   pega un hachazo adelante. 4 de vida.
## Si no te ven (más de 200 px o a otra altura) patrullan su superficie. Se los puede pisar.
## Cuadros HD de PixelLab en assets/sprites/skel/<arch|axe>/<anim>/, lienzo de 68x68 dibujado a la mitad:
## idle (respira, 9 cuadros en loop), walk, atk, hurt (se dobla con el golpe) y death.

const GRAV := 900.0
const DIR := "res://assets/sprites/skel/"
const CANVAS := 68.0
const FOOT_Y := 57.0  # fila de los pies en el lienzo
const HP := {"skarch": 3, "skaxe": 4}
const SPEED := {"skarch": 34.0, "skaxe": 42.0}
const EnemyArrow := preload("res://scripts/enemy_arrow.gd")
const BONE := [Color("e0d7b9"), Color("b5a98d"), Pal.S]  # huesitos que saltan

var kind := "skarch"
var zone := 0
var min_x := 0.0
var max_x := 99999.0
var on_ground_only := false  # en el piso puede recorrer toda la zona

var hp := 3
var face := -1.0
var pdir := 1.0
var cool := 1.0
var windup := 0.0
var swing_t := 9.0
var swing_hit := false
var shoot_t := -1.0
var shot := false
var stun := 0.0
var knock := 0.0
var flash := 0.0
var spawn := 0.0
var dead := false
var dead_t := 0.0
var squash := Vector2.ONE
var anim_t := 0.0
var ven_t := 0.0
var ven_k := 0.0
var parry_t := 0.0  # mareado por el parry del caballero: no lastima y el próximo espadazo es crítico
var sprite: Sprite2D
var hurtbox: Area2D
var target: Area2D
var hero: Player
var game  # main.gd
var frames := {}  # anim -> [Texture2D]


func _ready() -> void:
	add_to_group("enemigos")
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	floor_snap_length = 2.0
	hp = HP.get(kind, 3)
	cool = 0.8 + randf() * 1.2
	pdir = -1.0 if randf() < 0.5 else 1.0
	spawn = 0.55
	anim_t = randf() * 2.0
	hero = get_tree().get_first_node_in_group("heroe") as Player
	game = get_tree().get_first_node_in_group("juego")
	_load_frames()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 18)
	shape.shape = rect
	shape.position = Vector2(0, -9)
	add_child(shape)

	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-CANVAS / 2.0, -FOOT_Y)
	sprite.texture = _frame("idle", 0)
	add_child(sprite)

	hurtbox = Area2D.new()
	hurtbox.collision_layer = 0
	hurtbox.set_collision_layer_value(4, true)
	hurtbox.collision_mask = 0
	hurtbox.set_collision_mask_value(3, true)
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(8, 18)
	hs.shape = hr
	hs.position = Vector2(0, -9)
	hurtbox.add_child(hs)
	add_child(hurtbox)

	target = Area2D.new()
	target.collision_layer = 0
	target.set_collision_layer_value(5, true)
	target.collision_mask = 0
	target.monitoring = false
	var ts := CollisionShape2D.new()
	var tr := RectangleShape2D.new()
	tr.size = Vector2(12, 20)
	ts.shape = tr
	ts.position = Vector2(0, -10)
	target.add_child(ts)
	add_child(target)
	sprite.modulate.a = 0.0


## Los cuadros de los dos esqueletos, para cargarlos en segundo plano antes de que aparezcan.
static func asset_paths() -> Array:
	var out: Array = []
	for folder in ["arch", "axe"]:
		for anim in ["idle", "walk", "atk", "hurt", "death"]:
			var i := 0
			while ResourceLoader.exists("%s%s/%s/frame_%03d.png" % [DIR, folder, anim, i]):
				out.append("%s%s/%s/frame_%03d.png" % [DIR, folder, anim, i])
				i += 1
	return out


func _load_frames() -> void:
	var folder := DIR + ("arch" if kind == "skarch" else "axe") + "/"
	for anim in ["idle", "walk", "atk", "hurt", "death"]:
		var list: Array = []
		var i := 0
		while ResourceLoader.exists("%s%s/frame_%03d.png" % [folder, anim, i]):
			list.append(load("%s%s/frame_%03d.png" % [folder, anim, i]))
			i += 1
		frames[anim] = list


func _frame(anim: String, i: int) -> Texture2D:
	var list: Array = frames.get(anim, [])
	if list.is_empty():
		list = frames.get("idle", [])
	if list.is_empty():
		return null
	return list[clampi(i, 0, list.size() - 1)]


## Rectángulo del cuerpo (para las trampas que caen).
func hit_rect() -> Rect2:
	return Rect2(global_position.x - 4, global_position.y - 18, 8, 18)


func _physics_process(dt: float) -> void:
	flash -= dt
	anim_t += dt
	if dead:
		dead_t += dt
		var n: int = frames.get("death", []).size()
		sprite.texture = _frame("death", int(dead_t * 12.0))
		squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
		_apply_look()
		var hold := maxf(0.6, n / 12.0 + 0.35)
		sprite.material = Fx.silhouette(Color.WHITE) if flash > 0.0 else null
		sprite.modulate = Color.WHITE if flash > 0.0 else Color(1, 1, 1, 1.0 - clampf((dead_t - hold) / 0.35, 0.0, 1.0))
		if dead_t > hold + 0.35:
			queue_free()
		return
	if spawn > 0.0:  # sale de la tierra: sube desde abajo y no lastima
		spawn -= dt
		var k := clampf(1.0 - spawn / 0.55, 0.0, 1.0)
		sprite.modulate.a = k
		sprite.position.y = roundf((1.0 - k) * 10.0)
		sprite.texture = _frame("idle", 0)
		_apply_look()
		if randf() < 0.4:
			Fx.part(get_parent(), global_position + Vector2(randf_range(-5, 5), 0), Vector2(randf_range(-10, 10), -30), 120.0, 0.3, Pal.SS)
		if randf() < 0.25:
			Fx.chunks(get_parent(), global_position + Vector2(randf_range(-4, 4), 0), 1, [Pal.SS, Color("c8b090")], 40.0, 30.0, global_position.y, 0.5, 0.4)
		return
	sprite.position.y = 0.0
	if ven_t > 0.0:
		_venom_tick(dt)
		if dead:
			return

	if parry_t > 0.0:
		parry_t -= dt
		if Engine.get_physics_frames() % 6 == 0:
			var a := Time.get_ticks_msec() / 1000.0 * 9.0
			Fx.part(get_parent(), global_position + Vector2(cos(a) * 5.0, -22.0 + sin(a) * 1.5), Vector2.ZERO, 0.0, 0.16, Pal.Y if int(a) % 2 == 0 else Pal.W)
	var dir := _think(dt)
	var spd: float = SPEED.get(kind, 36.0)
	if stun > 0.0:
		stun -= dt
		if is_on_floor():
			velocity.x *= maxf(0.0, 1.0 - 8.0 * dt)
	elif windup > 0.0 or shoot_t >= 0.0 or swing_t < 0.3:
		velocity.x *= maxf(0.0, 1.0 - 10.0 * dt)
	else:
		var want := dir * spd
		velocity.x += signf(want - velocity.x) * minf(absf(want - velocity.x), 400.0 * dt)
	velocity.y = minf(velocity.y + GRAV * dt, 280.0)
	if knock != 0.0:
		velocity.x += knock
		knock *= maxf(0.0, 1.0 - 6.0 * dt)
		if absf(knock) < 6.0:
			knock = 0.0
	move_and_slide()
	if knock != 0.0:
		velocity.x -= knock
	if position.x < min_x:
		position.x = min_x
		pdir = 1.0
		knock = 0.0
	elif position.x > max_x:
		position.x = max_x
		pdir = -1.0
		knock = 0.0
	_attacks(dt)
	_touch_hero()
	_animate(dt)


## Decide hacia dónde caminar (-1, 0, 1) como aiMob del original.
func _think(dt: float) -> float:
	cool -= dt
	if windup > 0.0 or shoot_t >= 0.0 or stun > 0.0:
		return 0.0
	var dx := 999.0
	var dy := 999.0
	if hero != null and not hero.dead and game != null and game.state == "play":
		dx = hero.global_position.x - global_position.x
		dy = hero.global_position.y - global_position.y
	var dist := absf(dx)
	if kind == "skarch":
		if absf(dy) < 14.0 and dist < 200.0:
			face = signf(dx) if dx != 0.0 else face
			if cool <= 0.0 and dist < 170.0 and is_on_floor():
				shoot_t = 0.0
				shot = false
				cool = 1.6 + randf() * 0.7
				Snd.play("alerta", {"rate": 1.5, "vol": 0.3})
			return _keep_on(-face if dist < 56.0 else (face if dist > 120.0 else 0.0))
	else:
		if absf(dy) < 26.0 and dist < 200.0:
			face = signf(dx) if dx != 0.0 else face
			if dist < 24.0 and absf(dy) < 14.0 and cool <= 0.0 and is_on_floor():
				windup = 0.38
				cool = 1.4
				Snd.play("alerta", {"rate": 0.9, "vol": 0.35})
				return 0.0
			return _keep_on(face if dist > 14.0 else 0.0)
	# patrulla: ida y vuelta por su superficie, despacio
	face = pdir
	if position.x <= min_x + 1.0:
		pdir = 1.0
	elif position.x >= max_x - 1.0:
		pdir = -1.0
	return pdir * 0.5


## No camina más allá de su superficie (las plataformas no tienen baranda).
func _keep_on(d: float) -> float:
	if d < 0.0 and position.x <= min_x + 1.0:
		return 0.0
	if d > 0.0 and position.x >= max_x - 1.0:
		return 0.0
	return d


func _attacks(dt: float) -> void:
	if stun > 0.0:
		windup = 0.0
		shoot_t = -1.0
		return
	if windup > 0.0:
		windup -= dt
		if windup <= 0.0:
			swing_t = 0.0
			swing_hit = false
			Snd.play("tajo", {"rate": 0.75, "vol": 0.7})
			Snd.play("huesos", {"vol": 0.4})
			velocity.x += face * 40.0
			squash = Vector2(1.2, 0.86)
	if swing_t < 0.3:
		swing_t += dt
		if swing_t < 0.14 and not swing_hit and hero != null and not hero.dead:
			var hb := Rect2(global_position.x + (1.0 if face > 0.0 else -19.0), global_position.y - 24, 18, 24)
			if hero.box().intersects(hb):
				swing_hit = true
				hero.hurt(global_position.x, 1, self)
		if swing_t >= 0.04 and swing_t - dt < 0.04:
			var at := global_position + Vector2(face * 14.0, 0)
			Fx.slash(get_parent(), global_position + Vector2(face * 2.0, -12), 13.0, -110.0, 60.0, face, Pal.S, 4.0, 0.13)
			Fx.dust(get_parent(), at, 3, 24.0, 4.0, 1.6)
			Fx.chunks(get_parent(), at, 3, [Pal.SS, Pal.S], 50.0, 30.0, global_position.y, 0.5, 0.5)
			Fx.shock(get_parent(), at, Pal.S, 9.0, 0.22)
			Fx.part(get_parent(), at + Vector2(0, -1), Vector2(face * 60.0, -40.0), 200.0, 0.25, Pal.W)
			Fx.shake(1.5, 0.1)
	if shoot_t >= 0.0:
		shoot_t += dt
		if shoot_t >= 0.26 and not shot:
			shot = true
			var a := EnemyArrow.new()
			a.face = face
			a.game = game
			a.global_position = global_position + Vector2(face * 7.0, -11.0)
			get_parent().add_child(a)
			Snd.play("disparo", {"rate": 0.85, "vol": 0.6})
			Fx.twinkle(get_parent(), a.global_position + Vector2(face * 2.0, 0), Pal.L, 2.5, 0.12)
			velocity.x -= face * 25.0
			squash = Vector2(0.85, 1.1)
		if shoot_t >= 0.5:
			shoot_t = -1.0


func _touch_hero() -> void:
	for body in hurtbox.get_overlapping_bodies():
		var p := body as Player
		if p == null or p.dead:
			continue
		var top := global_position.y - 18.0
		var stomp := p.velocity.y - velocity.y > 0.0 and p.prev_bottom <= top + 6.0
		for fb in p.recent_bottoms:
			if fb <= top + 5.0:
				stomp = true
		if p.stomp_inv > 0.0:
			continue
		if stomp:
			p.bounce()
			take_hit(1, 0, "stomp")
		elif parry_t <= 0.0:
			p.hurt(global_position.x, 1, self)


## Lo llama el escudo del caballero: el parry lo empuja, le corta el ataque y lo deja mareado.
func parried(d: float, t: float) -> void:
	if dead or spawn > 0.0:
		return
	stun = maxf(stun, t)
	parry_t = maxf(parry_t, t)
	windup = 0.0
	swing_t = 9.0
	shoot_t = -1.0
	knock = d * 135.0
	velocity.y = -150.0
	flash = 0.12
	squash = Vector2(1.25, 0.8)
	Snd.play("huesos", {"rate": 0.8})


## how: "arrow", "sword", "riposte" (crítico seguro), "stomp", "trap" o "poison", igual que los slimes.
func take_hit(dmg: int, from_dir: int, how: String = "arrow") -> void:
	if dead or spawn > 0.0:
		return
	var crit := how == "riposte" or (how != "trap" and how != "poison" and Fx.rand_crit())
	hp -= dmg * 3 if crit else dmg
	if crit:
		Fx.crit(get_parent(), global_position + Vector2(0, -10))
	if hp <= 0:
		_die(how, from_dir, crit)
		return
	flash = 0.12
	stun = 0.35
	windup = 0.0
	shoot_t = -1.0
	var kd := from_dir if from_dir != 0 else (-1 if randf() < 0.5 else 1)
	knock = kd * 100.0
	velocity.y = -90.0
	squash = Vector2(1.5, 0.6) if how == "stomp" else Vector2(1.25, 0.8)
	Snd.play("huesos", {"rate": 1.4, "vol": 0.6})
	if how == "stomp":
		Snd.play("pisoton")
	Fx.hitstop(0.035)
	Fx.hit(get_parent(), global_position + Vector2(-kd * 3.0, -11), Vector2(0, 1) if how == "stomp" else Vector2(kd, 0), Pal.W)
	Fx.chunks(get_parent(), global_position + Vector2(0, -12), 3, BONE, 55.0, 40.0, global_position.y, 0.5, 0.5)
	Fx.popup(get_parent(), global_position + Vector2(0, -24), "-%d" % (dmg * 3 if crit else dmg), Pal.W)


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
		Fx.part(get_parent(), global_position + Vector2(randf_range(-4, 4), -randf_range(4, 16)), Vector2(0, -18), -10.0, 0.45, Pal.L if randf() < 0.5 else Pal.G)
	if ven_k <= 0.0:
		ven_k = 0.7
		hp -= 1
		flash = 0.08
		Snd.play("huesos", {"rate": 1.6, "vol": 0.4})
		Fx.popup(get_parent(), global_position + Vector2(0, -24), "-1", Pal.L)
		if hp <= 0:
			_die("poison", 0, false)


func _die(how: String, from_dir: int, crit: bool) -> void:
	dead = true
	dead_t = 0.0
	flash = 0.2 if crit else 0.1
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	target.set_deferred("monitorable", false)
	squash = Vector2(1.3, 0.75)
	position.x += from_dir * 3
	Fx.hitstop(0.05 if how == "stomp" else 0.04)
	Fx.shake(2.0, 0.14)
	Snd.play("huesos", {"rate": 1.1, "vol": 0.7})
	Snd.play("explotar", {"delay": 0.05, "vol": 0.6, "rate": 1.3})
	# se desarma: estrella, huesitos que rebotan, polvo de tumba y el brillo verde que se escapa
	var at := global_position + Vector2(0, -10)
	Fx.hit(get_parent(), at, Vector2(0, 1) if how == "stomp" else Vector2(from_dir if from_dir != 0 else 1, -0.2), Pal.W, crit)
	Fx.chunks(get_parent(), at, 12 if crit else 8, BONE, 110.0 if crit else 80.0, 60.0, global_position.y, 1.0, 0.9)
	Fx.dust(get_parent(), global_position, 4, 22.0, 4.0, 2.0, Pal.SS)
	for i in 4:
		Fx.part(get_parent(), global_position + Vector2(randf_range(-4, 4), -randf_range(10, 18)), Vector2(randf_range(-8, 8), -30), -25.0, 0.6, Pal.L)
	if game != null:
		game.slime_killed(self, how, crit)


func _animate(dt: float) -> void:
	if parry_t > 0.0:  # mareado: doblado, tambaleándose
		sprite.texture = _frame("hurt", 1)
		sprite.rotation = sin(Time.get_ticks_msec() / 1000.0 * 10.0) * 0.08
	elif stun > 0.0:  # se dobla con el golpe y se vuelve a parar
		var hn: int = frames.get("hurt", []).size()
		sprite.texture = _frame("hurt", int((1.0 - stun / 0.35) * hn)) if hn > 0 else _frame("walk", 0)
	elif windup > 0.0:  # levanta el hacha
		sprite.texture = _frame("atk", 1 if windup > 0.19 else 2)
	elif swing_t < 0.3:  # hachazo al piso y la vuelve a subir
		sprite.texture = _frame("atk", 3 + int(swing_t / 0.3 * 3.0))
	elif shoot_t >= 0.0:
		sprite.texture = _frame("atk", int(shoot_t / 0.5 * 6.0))
	elif absf(velocity.x) > 6.0:
		sprite.texture = _frame("walk", int(anim_t * (10.0 if absf(velocity.x) > 25.0 else 7.0)) % maxi(1, frames.get("walk", []).size()))
	else:  # respira (cada uno a su ritmo)
		sprite.texture = _frame("idle", int(anim_t * 9.0) % maxi(1, frames.get("idle", []).size()))
	if parry_t <= 0.0:
		sprite.rotation = 0.0
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
	_apply_look()
	sprite.material = Fx.silhouette(Color.WHITE) if flash > 0.0 else null
	if flash > 0.0:
		sprite.modulate = Color.WHITE
	elif windup > 0.0 and int(windup * 30.0) % 2 == 0:
		sprite.modulate = Color(1.6, 1.3, 1.3)
	elif ven_t > 0.0:
		sprite.modulate = Color(0.75, 1.25, 0.6)
	else:
		sprite.modulate = Color.WHITE


func _apply_look() -> void:
	sprite.scale = Vector2(0.5 * squash.x * (1.0 if face >= 0.0 else -1.0), 0.5 * squash.y)
