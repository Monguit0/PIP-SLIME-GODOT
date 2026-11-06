class_name Slime
extends CharacterBody2D
## Slimes del Reino, con la lógica del juego web:
## - verde (updateGreen): patrulla su superficie a saltitos, 1 de vida.
## - rojo (updateRed): te persigue por toda la zona y salta para alcanzarte, 2 de vida.
## Hoja HD: assets/sprites/slimes.png, 13 cuadros de 32x26 por fila (verde, rojo, tóxico, hielo),
## dibujada a la mitad (16x13 en el mundo). Cuadros: 0-7 respirar, 8 carga, 9 boca, 10 golpe, 11-12 reventar.

signal killed

const GRAV := 900.0
const FW := 32
const FH := 26
const SHEET := preload("res://assets/sprites/slimes.png")
const ROWS := {"green": 0, "red": 1, "toxic": 2, "ice": 3}
const HP := {"green": 1, "red": 2, "toxic": 1, "ice": 2}

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
var hero: Player


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
	hero = get_tree().get_first_node_in_group("heroe") as Player

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
	_set_frame(0)
	sprite.scale = Vector2.ZERO


func _physics_process(dt: float) -> void:
	flash -= dt
	if dead:
		dead_t += dt
		_set_frame(11 if dead_t < 0.07 else 12)
		sprite.modulate = Color(1, 1, 1, 1.0 - clampf((dead_t - 0.2) / 0.3, 0.0, 1.0))
		if dead_t > 0.5:
			queue_free()
		return
	if spawn > 0.0:  # aparece inflándose y no lastima
		spawn -= dt
		var k := clampf(1.0 - spawn / 0.5, 0.0, 1.0)
		sprite.scale = Vector2(0.5, 0.5) * Vector2(k, k)
		sprite.modulate.a = k
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
	else:
		velocity.x = dir * speed
		face = dir
	hop_t -= dt
	if hop_t <= 0.0 and is_on_floor():
		velocity.y = -150.0
		hop_t = 1.6 + randf() * 2.6
		squash = Vector2(0.7, 1.4)
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
		if is_on_floor():
			velocity.x *= maxf(0.0, 1.0 - 8.0 * dt)
	elif is_on_floor():
		var want := 0.0 if absf(dx) > 220.0 else signf(dx) * speed
		velocity.x += signf(want - velocity.x) * minf(absf(want - velocity.x), 320.0 * dt)
		if absf(dx) < 220.0:
			face = signf(dx) if dx != 0.0 else face
		jump_t -= dt
		if jump_t <= 0.0 and absf(dx) < 220.0 and ((above and absf(dx) < 80.0) or absf(dx) < 34.0):
			velocity.y = -285.0 if above else -175.0
			velocity.x = signf(dx) * speed * 1.5
			jump_t = 0.8 + randf() * 0.7
			squash = Vector2(0.65, 1.45)
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
			take_hit(1, 0, true)
		else:
			p.hurt(global_position.x)


func take_hit(dmg: int, from_dir: int, stomp: bool = false) -> void:
	if dead or spawn > 0.0:
		return
	hp -= dmg
	flash = 0.12
	stun = 0.35
	if from_dir != 0:
		knock = from_dir * 110.0
	squash = Vector2(1.8, 0.35) if stomp else Vector2(1.3, 0.75)
	var cols := [Pal.L, Pal.G, Pal.W] if kind != "red" else [Pal.O, Pal.R, Pal.W]
	Fx.burst(get_parent(), global_position + Vector2(0, -4), 6, cols, 60.0, 40.0)
	Fx.popup(get_parent(), global_position + Vector2(0, -12), str(dmg), Color.WHITE)
	if stomp:
		Fx.hitstop(0.055)
		Fx.shake(2.0, 0.14)
	if hp <= 0:
		_die(cols)
	elif not stomp:
		Fx.hitstop(0.03)


func _die(cols: Array) -> void:
	dead = true
	dead_t = 0.0
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	Fx.shake(2.0, 0.15)
	Fx.hitstop(0.05)
	Fx.burst(get_parent(), global_position + Vector2(0, -4), 14, cols, 90.0, 60.0, 0.5)
	killed.emit()


func _animate(dt: float) -> void:
	var tt := Time.get_ticks_msec() / 1000.0
	var fps := 12.0 if kind == "red" else 8.0
	var f := 10 if stun > 0.0 else int(tt * fps + phase) % 8
	_set_frame(f)
	sprite.flip_h = face < 0.0
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
	sprite.scale = squash * 0.5
	sprite.modulate = Color(3, 3, 3) if flash > 0.0 else Color.WHITE


func _set_frame(i: int) -> void:
	sprite.region_rect = Rect2(i * FW, ROWS.get(kind, 0) * FH, FW, FH)
