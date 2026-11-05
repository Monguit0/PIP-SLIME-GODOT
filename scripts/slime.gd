class_name Slime
extends CharacterBody2D
## Slime verde: patrulla su plataforma a saltitos (updateGreen del juego web).
## Hoja: assets/sprites/slimes.png, 13 cuadros de 32x26 por fila (verde, rojo, tóxico, hielo).
## Cuadros: 0-7 respirar, 8 carga, 9 boca abierta, 10 golpe, 11-12 reventar.

signal killed

const GRAV := 900.0
const FW := 32
const FH := 26
const SHEET := preload("res://assets/sprites/slimes.png")
const ROWS := {"green": 0, "red": 1, "toxic": 2, "ice": 3}

@export var kind := "green"
@export var min_x := 0.0
@export var max_x := 99999.0

var hp := 2
var dir := 1.0
var speed := 18.0
var hop_t := 0.0
var stun := 0.0
var flash := 0.0
var dead := false
var dead_t := 0.0
var squash := Vector2.ONE
var phase := 0.0
var sprite: Sprite2D
var hurtbox: Area2D


func _ready() -> void:
	add_to_group("enemigos")
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	dir = -1.0 if randf() < 0.5 else 1.0
	hop_t = randf_range(0.5, 2.5)
	phase = randf() * 8.0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 12)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)

	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.region_enabled = true
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
	hr.size = Vector2(18, 14)
	hs.shape = hr
	hs.position = Vector2(0, -7)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	_set_frame(0)


func _physics_process(dt: float) -> void:
	if dead:
		dead_t += dt
		_set_frame(11 if dead_t < 0.07 else 12)
		sprite.modulate.a = 1.0 - clampf((dead_t - 0.2) / 0.3, 0.0, 1.0)
		if dead_t > 0.5:
			queue_free()
		return

	flash -= dt
	if stun > 0.0:
		stun -= dt
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * dt)
	else:
		velocity.x = dir * speed
	hop_t -= dt
	if hop_t <= 0.0 and is_on_floor() and stun <= 0.0:
		velocity.y = -150.0
		hop_t = 1.6 + randf() * 2.6
		squash = Vector2(0.7, 1.4)
	velocity.y += GRAV * dt
	var fall := velocity.y
	var was_floor := is_on_floor()
	move_and_slide()
	if is_on_floor() and not was_floor and fall > 120.0:
		squash = Vector2(1.4, 0.6)
	if position.x < min_x:
		position.x = min_x
		dir = 1.0
	elif position.x > max_x:
		position.x = max_x
		dir = -1.0
	elif is_on_wall():
		dir = -dir

	_touch_hero()
	_animate(dt)


func _touch_hero() -> void:
	for body in hurtbox.get_overlapping_bodies():
		var p := body as Player
		if p != null and not p.dead:
			# pisotón: viene cayendo y tiene los pies arriba del medio del slime
			if p.velocity.y > 20.0 and p.global_position.y < global_position.y - 6.0:
				p.bounce()
				take_hit(2, int(signf(p.velocity.x)) if p.velocity.x != 0.0 else p.face, true)
			else:
				p.hurt(global_position.x)


func take_hit(dmg: int, from_dir: int, stomp: bool = false) -> void:
	if dead:
		return
	hp -= dmg
	flash = 0.1
	stun = 0.3
	velocity.x = from_dir * 110.0
	squash = Vector2(1.3, 0.75) if stomp else Vector2(0.8, 1.2)
	Fx.burst(get_parent(), global_position + Vector2(0, -6), 6, [Color("7ad94a"), Color("c8f080")], 60.0, 40.0)
	Fx.popup(get_parent(), global_position + Vector2(0, -16), str(dmg), Color.WHITE)
	if hp <= 0:
		_die()
	else:
		Fx.hitstop(0.03)


func _die() -> void:
	dead = true
	dead_t = 0.0
	collision_mask = 0
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	Fx.shake(2.0, 0.15)
	Fx.hitstop(0.05)
	Fx.burst(get_parent(), global_position + Vector2(0, -6), 14, [Color("7ad94a"), Color("3f9e4a"), Color.WHITE], 90.0, 60.0, 0.5)
	killed.emit()


func _animate(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var f := 10 if stun > 0.0 else int(t * 8.0 + phase) % 8
	_set_frame(f)
	sprite.flip_h = dir < 0.0
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
	sprite.scale = squash
	sprite.modulate = Color(3, 3, 3) if flash > 0.0 else Color.WHITE


func _set_frame(i: int) -> void:
	sprite.region_rect = Rect2(i * FW, ROWS.get(kind, 0) * FH, FW, FH)
