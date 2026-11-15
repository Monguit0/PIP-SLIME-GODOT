extends CharacterBody2D
## Base de los bichos del Bosque Oscuro (hongo y planta): lo que todos comparten con los demás enemigos
## (vida, golpes, quemadura, parry, muerte, posesión del modo Villano, marcas) para que cada uno solo
## escriba cómo se mueve y cómo ataca. Los cuadros se cargan de DIR/<anim>/frame_NNN.png.

const GRAV := 900.0
const GROUND := 128.0
const Turbo := preload("res://scripts/turbo.gd")

# lo que define cada bicho en _setup()
var dir_path := ""
var anims: Array = []
var canvas := 64.0
var foot_y := 62.0
var draw_scale := 0.45
var body_w := 10.0
var body_h := 20.0
var base_hp := 3
var walk_speed := 30.0
var ctrl_speed := 50.0
var jump_v := 0.0          # 0: no salta
var mob_title := "BICHO"
var goo: Array = [Pal.W]
var faces_right := true
var top_mark := -30.0

var kind := "mob"
var zone := 0
var min_x := 0.0
var max_x := 99999.0
var hp := 3
var max_hp := 3
var face := -1.0
var pdir := 1.0
var cool := 1.0
var windup := 0.0
var stun := 0.0
var knock := 0.0
var flash := 0.0
var spawn := 0.0
var dead := false
var dead_t := 0.0
var squash := Vector2.ONE
var anim_t := 0.0
var burn_t := 0.0
var burn_k := 0.0
var parry_t := 0.0
var sprite: Sprite2D
var hurtbox: Area2D
var hero: Player
var game
var frames := {}
var villain := false
var ctrl := false
var show_hp := 0.0
var drop_t := 0.0
var charging := false
var aim_x := 0.0
var turbo = Turbo.new()
var immune := false        # no le entra ningún golpe (la planta bajo tierra)
var touch := true          # tocarlo lastima
var idle_anim := "idle"    # el cuadro con el que aparece
var vanish := false        # al morir no deja cuerpo: se infla y desaparece de un saque


func _setup() -> void:
	pass


func _step(_dt: float) -> void:
	pass


func _anim() -> void:
	pass


func _on_death(_how: String, _from_dir: int) -> void:
	pass


func _ready() -> void:
	_setup()
	add_to_group("enemigos")
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	floor_snap_length = 2.0
	hp = base_hp
	max_hp = base_hp
	cool = 0.8 + randf() * 1.2
	pdir = -1.0 if randf() < 0.5 else 1.0
	spawn = 0.55
	anim_t = randf() * 2.0
	hero = get_tree().get_first_node_in_group("heroe") as Player
	game = get_tree().get_first_node_in_group("juego")
	for a in anims:
		var list: Array = []
		var i := 0
		while ResourceLoader.exists("%s%s/frame_%03d.png" % [dir_path, a, i]):
			list.append(load("%s%s/frame_%03d.png" % [dir_path, a, i]))
			i += 1
		frames[a] = list
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, body_h - 2.0)
	shape.shape = rect
	shape.position = Vector2(0, -(body_h - 2.0) / 2.0)
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-canvas / 2.0, -foot_y)
	sprite.texture = frame(idle_anim, 0)
	add_child(sprite)
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 0
	hurtbox.set_collision_layer_value(4, true)
	hurtbox.collision_mask = 0
	hurtbox.set_collision_mask_value(3, true)
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(body_w, body_h)
	hs.shape = hr
	hs.position = Vector2(0, -body_h / 2.0)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	sprite.modulate.a = 0.0


func frame(a: String, i: int) -> Texture2D:
	var list: Array = frames.get(a, [])
	if list.is_empty():
		return null
	return list[clampi(i, 0, list.size() - 1)]


func count(a: String) -> int:
	return maxi(1, frames.get(a, []).size())


func hit_rect() -> Rect2:
	if immune:
		return Rect2(global_position.x, global_position.y + 900.0, 0, 0)
	return Rect2(global_position.x - body_w / 2.0, global_position.y - body_h, body_w, body_h)


func mob_name() -> String:
	return mob_title


func mob_hint() -> String:
	return ""


func playing() -> bool:
	return game == null or game.state == "play"


func dev():
	return game.vdev if game != null else null


func nearest_hero() -> Player:
	var best: Player = null
	var bd := 1e9
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p == null or p.dead:
			continue
		var d := absf(p.global_position.x - global_position.x) + absf(p.global_position.y - global_position.y) * 1.5
		if d < bd:
			bd = d
			best = p
	return best


func heroes_in(r: Rect2) -> Array:
	var out: Array = []
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p != null and not p.dead and p.box().intersects(r):
			out.append(p)
	return out


func possess() -> void:
	ctrl = true
	cool = 0.0
	stun = 0.0
	flash = 0.12
	turbo.reset()
	squash = Vector2(0.75, 1.35)
	if game != null:
		min_x = float(game.ZONES[zone].start + 6)
		max_x = float(game.gates[zone].x - 6) if zone < game.gates.size() else float(game.ZONES[zone].end - 6)
	var at := global_position + Vector2(0, -10)
	Fx.burst(get_parent(), at, 12, [Pal.Y, Pal.C, Pal.W], 60.0, 30.0, 0.5, 0.0)
	Fx.ring(get_parent(), at, Pal.C, 0.0, 14.0, 1.0, 0.3)


func _physics_process(dt: float) -> void:
	flash -= dt
	anim_t += dt
	queue_redraw()
	if dead and vanish:
		dead_t += dt
		var k := clampf(dead_t / 0.14, 0.0, 1.0)
		look()
		sprite.scale *= Vector2(1.0 + k * 0.9, 1.0 - k * 0.55)
		sprite.material = Fx.silhouette(Color.WHITE)
		sprite.modulate = Color(1, 1, 1, 1.0 - k)
		if dead_t > 0.14:
			queue_free()
		return
	if dead:
		dead_t += dt
		velocity.y = minf(velocity.y + GRAV * dt, 280.0)
		velocity.x *= maxf(0.0, 1.0 - 6.0 * dt)
		move_and_slide()
		sprite.texture = frame("death", int(dead_t * 12.0))
		squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
		look()
		var hold := count("death") / 12.0 + 0.5
		sprite.material = Fx.silhouette(Color.WHITE) if flash > 0.0 else null
		sprite.modulate = Color.WHITE if flash > 0.0 else Color(1, 1, 1, 1.0 - clampf((dead_t - hold) / 0.35, 0.0, 1.0))
		if dead_t > hold + 0.35:
			queue_free()
		return
	if spawn > 0.0:  # brota de la tierra
		spawn -= dt
		var k := clampf(1.0 - spawn / 0.55, 0.0, 1.0)
		sprite.modulate.a = k
		sprite.texture = frame(idle_anim, 0)
		look()
		sprite.position.y = roundf((1.0 - k) * 10.0)
		if randf() < 0.4:
			Fx.part(get_parent(), global_position + Vector2(randf_range(-5, 5), 0), Vector2(randf_range(-10, 10), -30), 120.0, 0.3, Pal.SS)
		return
	if burn_t > 0.0:
		burn_t -= dt
		burn_k -= dt
		if burn_k <= 0.0:
			burn_k = 0.8
			take_hit(1, 0, "burn")
			if dead:
				return
	if parry_t > 0.0:
		parry_t -= dt
	cool -= dt
	if villain:
		show_hp -= dt
		hero = nearest_hero()
		if drop_t > 0.0:
			drop_t -= dt
			if drop_t <= 0.0:
				set_collision_mask_value(2, true)
	_step(dt)
	if touch and not immune:
		_touch_hero()
	_anim()
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
	look()
	sprite.material = Fx.silhouette(Color.WHITE) if flash > 0.0 else null
	sprite.modulate = Color.WHITE if flash > 0.0 else (Color(1.35, 0.95, 0.7) if burn_t > 0.0 else Color.WHITE)


## Lo que pide el jugador para moverse (-1, 0, 1); de paso atiende el salto y el bajar de plataforma.
func ctrl_dir(can_turn: bool = true) -> float:
	if not playing() or stun > 0.0:
		return 0.0
	var d := float(int(Ctl.down(dev(), "derecha")) - int(Ctl.down(dev(), "izquierda")))
	if d != 0.0 and can_turn:
		face = d
	if Ctl.tap(dev(), "saltar") and is_on_floor():
		if Ctl.down(dev(), "abajo") and global_position.y < GROUND - 2.0:
			set_collision_mask_value(2, false)
			drop_t = 0.25
		elif jump_v > 0.0:
			velocity.y = -jump_v
			squash = Vector2(0.75, 1.3)
			Snd.play("salto", {"rate": 1.1})
	return d


## Camina: acelera hacia dir * top, cae, recibe el empujón de los golpes y no sale de su zona.
func walk(dir: float, top: float, dt: float) -> void:
	if stun > 0.0:
		stun -= dt
		dir = 0.0
	var acc := (700.0 if is_on_floor() else 450.0) * dt
	velocity.x += clampf(dir * top - velocity.x, -acc, acc)
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
	elif position.x > max_x:
		position.x = max_x
		pdir = -1.0


func _touch_hero() -> void:
	for body in hurtbox.get_overlapping_bodies():
		var p := body as Player
		if p == null or p.dead or p.stomp_inv > 0.0:
			continue
		var top := global_position.y - body_h
		var stomp := p.velocity.y - velocity.y > 0.0 and p.prev_bottom <= top + 6.0
		if stomp:
			p.bounce()
			take_hit(1, 0, "stomp")
		elif parry_t <= 0.0:
			p.hurt(global_position.x, 1, self)


func parried(d: float, t: float) -> void:
	if dead or spawn > 0.0 or immune:
		return
	stun = maxf(stun, t)
	parry_t = maxf(parry_t, t)
	windup = 0.0
	knock = d * 135.0
	velocity.y = -150.0
	flash = 0.12
	_interrupt()


func _interrupt() -> void:
	pass


func take_hit(dmg: int, from_dir: int, how: String = "arrow") -> void:
	if dead or spawn > 0.0 or immune:
		return
	var crit := how == "riposte" or (how != "trap" and how != "poison" and how != "burn" and Fx.rand_crit())
	hp -= dmg * 3 if crit else dmg
	if crit:
		Fx.crit(get_parent(), global_position + Vector2(0, -10))
	var kd := from_dir if from_dir != 0 else (-1 if randf() < 0.5 else 1)
	if hp <= 0:
		_die(how, kd, crit)
		return
	flash = 0.12
	stun = 0.3
	show_hp = 2.0
	_interrupt()
	if ctrl:
		Fx.flash_red = 0.14
		Fx.shake(3.0, 0.18)
	knock = kd * 90.0
	velocity.y = -80.0
	squash = Vector2(1.5, 0.6) if how == "stomp" else Vector2(1.25, 0.8)
	Snd.play("baba", {"rate": 0.8, "vol": 0.6})
	Fx.hitstop(0.035)
	Fx.hit(get_parent(), global_position + Vector2(-kd * 3.0, -body_h / 2.0), Vector2(kd, 0), Pal.W)
	Fx.burst(get_parent(), global_position + Vector2(0, -body_h / 2.0), 5, goo, 60.0, 30.0, 0.35, 260.0)
	Fx.popup(get_parent(), global_position + Vector2(0, -body_h - 6.0), "-%d" % (dmg * 3 if crit else dmg), Pal.W)


func apply_venom() -> void:
	apply_burn()


func apply_burn(_long: bool = false, _green: bool = false) -> void:
	if dead or immune:
		return
	burn_t = 2.4
	burn_k = 0.8


func _die(how: String, from_dir: int, crit: bool) -> void:
	dead = true
	dead_t = 0.0
	flash = 0.12
	velocity = Vector2(from_dir * 40.0, -60.0)
	hurtbox.set_deferred("monitoring", false)
	squash = Vector2(1.3, 0.75)
	Fx.hitstop(0.07)
	Fx.shake(2.5, 0.18)
	Snd.play("explotar", {"vol": 0.6, "rate": 1.4})
	var mid := global_position + Vector2(0, -body_h / 2.0)
	Fx.ring(get_parent(), mid, Pal.W, 0.0, 14.0, 1.0, 0.25)
	Fx.burst(get_parent(), mid, 14 if crit else 10, goo, 100.0, 50.0, 0.5, 300.0)
	Fx.hit(get_parent(), mid, Vector2(from_dir, -0.2), Pal.W, crit)
	_on_death(how, from_dir)
	if game != null:
		game.slime_killed(self, how, crit)


func look() -> void:
	var fl := 1.0 if (face >= 0.0) == faces_right else -1.0
	sprite.scale = Vector2(draw_scale * squash.x * fl, draw_scale * squash.y)


## barrita de recarga de una habilidad, debajo del bicho (k: 0 a 1)
func draw_meter(k: float, y: float, col: Color) -> void:
	draw_rect(Rect2(-7.5, y - 0.5, 15.0, 3.0), Pal.K)
	draw_rect(Rect2(-7.0, y, 14.0 * clampf(k, 0.0, 1.0), 2.0), col if k < 1.0 else (Pal.W if int(anim_t * 8.0) % 2 == 0 else col))


func _draw() -> void:
	if dead or spawn > 0.0 or not villain:
		return
	_draw_extra()
	if ctrl and not immune:
		Turbo.draw_marker(self, top_mark)
	if hp < max_hp and (show_hp > 0.0 or ctrl) and not immune:
		Turbo.draw_hp(self, top_mark + 4.0, hp, max_hp)


func _draw_extra() -> void:
	pass
