class_name Player
extends CharacterBody2D
## Pip arquero. Valores copiados del juego web (index.html: CHARS.archer, SK, GRAV, DJ).

signal hearts_changed
signal died

const GRAV := 900.0
const FALL_MUL := 1.25
const MAX_FALL := 270.0
const SPEED := 92.0
const JUMP := 268.0
const DJ := 0.86            # el doble salto tiene el 86% del impulso
const ACC_GROUND := 900.0
const ACC_AIR := 620.0
const FRIC_GROUND := 1100.0
const FRIC_AIR := 300.0
const COYOTE := 0.09
const BUFFER := 0.11
const DROP_T := 0.22
const SHOT_COOL := 0.25
# energía y dash
const EN_MAX := 100.0
const EN_REGEN := 15.0
const EN_DELAY := 0.7
const DASH_COST := 34.0
const DASH_T := 0.16
const DASH_V := 330.0
const GHOST_T := 0.34
# carga del arco
const CHG_ON := 0.2
const CHG_FULL := 0.75
const INVULN := 1.0

const ArrowScript := preload("res://scripts/arrow.gd")
const PIP_DIR := "res://assets/sprites/pip/"

var max_hearts := 3
var hearts := 3
var face := 1
var coyote := 0.0
var buffer := 0.0
var double_jumped := false
var jump_cut := false
var dash_t := 0.0
var ghost_t := 0.0
var air_dash := false
var energy := EN_MAX
var energy_delay := 0.0
var shot_cool := 0.0
var charge := -1.0          # -1 = no está cargando
var invuln := 0.0
var drop_t := 0.0
var hurt_t := 0.0
var dead := false
var squash := Vector2.ONE
var energy_flash := 0.0

var sprite: AnimatedSprite2D
var prev_bottom := 0.0
var stomp_inv := 0.0
var shoot_t := 0.0


func _ready() -> void:
	add_to_group("heroe")
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	floor_snap_length = 3.0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 18)
	shape.shape = rect
	shape.position = Vector2(0, -9)
	add_child(shape)

	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _build_frames()
	sprite.centered = true
	sprite.offset = Vector2(0, -23) # lienzo de 48x48: los pies quedan en la fila 46
	sprite.scale = Vector2(0.5, 0.5) # píxeles HD: se dibuja a la mitad, como en el original
	add_child(sprite)
	sprite.play("idle")


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var anims := {"idle": 6.0, "run": 12.0, "jump": 12.0, "fall": 6.0, "shoot": 16.0, "hurt": 14.0, "dash": 18.0, "death": 10.0}
	for anim in anims:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, anims[anim])
		sf.set_animation_loop(anim, anim in ["idle", "run", "fall"])
		var i := 0
		while true:
			var path := "%s%s/frame_%03d.png" % [PIP_DIR, anim, i]
			if not ResourceLoader.exists(path):
				break
			sf.add_frame(anim, load(path))
			i += 1
	# si falta alguna animación, usa la quieta; si no hay nada, un muñequito de colores
	var still: Texture2D = null
	if ResourceLoader.exists(PIP_DIR + "east.png"):
		still = load(PIP_DIR + "east.png")
	else:
		still = _placeholder()
	for anim in anims:
		if sf.get_frame_count(anim) == 0:
			if anim == "fall" and sf.get_frame_count("jump") > 0:
				sf.add_frame(anim, sf.get_frame_texture("jump", 0))
			elif anim != "idle" and sf.get_frame_count("idle") > 0:
				sf.add_frame(anim, sf.get_frame_texture("idle", 0))
			else:
				sf.add_frame(anim, still)
	return sf


func _placeholder() -> Texture2D:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(19, 18, 10, 22), Color("1c1c28"))
	img.fill_rect(Rect2i(20, 19, 8, 7), Color("d9473f"))  # capucha roja
	img.fill_rect(Rect2i(22, 21, 5, 4), Color("f0c08a"))  # cara
	img.fill_rect(Rect2i(20, 27, 8, 9), Color("3f9e4a"))  # túnica verde
	img.fill_rect(Rect2i(30, 20, 1, 14), Color("8a5a2b"))  # arco
	return ImageTexture.create_from_image(img)


func _physics_process(dt: float) -> void:
	if dead:
		velocity.y = minf(velocity.y + GRAV * dt, MAX_FALL)
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * dt)
		move_and_slide()
		_animate(dt)
		return

	var dir := int(Input.is_action_pressed("derecha")) - int(Input.is_action_pressed("izquierda"))
	var jump_pressed := Input.is_action_just_pressed("saltar")
	var jump_held := Input.is_action_pressed("saltar")
	var down := Input.is_action_pressed("abajo")

	_timers(dt)
	_special(dt, Input.is_action_just_pressed("especial"))

	# saltar corta la carga del arco y el dash
	if jump_pressed and coyote > 0.0:
		charge = -1.0
		dash_t = 0.0

	var dashing := dash_t > 0.0
	var slow := 0.0 if charge >= CHG_ON else 1.0  # cargando no se mueve
	var top := SPEED * slow

	# horizontal
	var acc := ACC_GROUND if is_on_floor() else ACC_AIR
	if dashing:
		pass
	elif dir != 0 and slow > 0.0:
		velocity.x += dir * acc * dt
		face = dir
	else:
		if dir != 0:
			face = dir
		var f := (FRIC_GROUND if is_on_floor() else FRIC_AIR) * dt * (1.0 if slow > 0.0 else 2.0)
		velocity.x = 0.0 if absf(velocity.x) <= f else velocity.x - signf(velocity.x) * f
	if not dashing:
		velocity.x = clampf(velocity.x, -top - 50.0, top + 50.0)
		if absf(velocity.x) > top:
			velocity.x -= signf(velocity.x) * minf(absf(velocity.x) - top, 500.0 * dt)

	# salto con coyote time, buffer, doble salto y salto corto
	coyote = COYOTE if is_on_floor() else coyote - dt
	buffer = BUFFER if jump_pressed else buffer - dt
	if buffer > 0.0 and coyote > 0.0 and not dashing:
		if down and is_on_floor() and _on_platform():
			_drop()
		else:
			velocity.y = -JUMP
			coyote = 0.0
			buffer = 0.0
			jump_cut = false
			squash = Vector2(0.7, 1.35)
			Fx.burst(get_parent(), global_position, 5, [Color.WHITE, Color("c8d0d8")], 30.0, 10.0)
	elif buffer > 0.0 and not is_on_floor() and not double_jumped and not dashing:
		double_jumped = true
		velocity.y = -JUMP * DJ
		buffer = 0.0
		jump_cut = false
		charge = -1.0
		squash = Vector2(0.75, 1.3)
		Fx.ring(get_parent(), global_position, Color(1, 1, 1, 0.8))
	if not jump_held and velocity.y < -60.0 and not jump_cut:
		velocity.y *= 0.45
		jump_cut = true
	if down and is_on_floor() and _on_platform() and not jump_held:
		_drop()

	if dashing:
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + GRAV * (FALL_MUL if velocity.y > 0.0 else 1.0) * dt, MAX_FALL)

	var fall_speed := velocity.y
	var was_floor := is_on_floor()
	prev_bottom = global_position.y
	move_and_slide()
	if is_on_floor():
		double_jumped = false
		air_dash = false
		if not was_floor and fall_speed > 120.0:
			squash = Vector2(1.35, 0.7)
			Fx.burst(get_parent(), global_position, 4, [Color("c8d0d8")], 25.0, 5.0)

	_attack(dt)
	_animate(dt)


func _timers(dt: float) -> void:
	shot_cool -= dt
	stomp_inv -= dt
	shoot_t -= dt
	invuln -= dt
	ghost_t -= dt
	hurt_t -= dt
	energy_flash -= dt
	if drop_t > 0.0:
		drop_t -= dt
		if drop_t <= 0.0:
			set_collision_mask_value(2, true)
	if dash_t > 0.0:
		dash_t -= dt
		if dash_t <= 0.0: # frena seco al terminar
			velocity.x = signf(velocity.x) * minf(absf(velocity.x), SPEED)
	energy_delay -= dt
	if energy_delay <= 0.0:
		energy = minf(EN_MAX, energy + EN_REGEN * dt)


func _special(_dt: float, pressed: bool) -> void:
	if not pressed or dash_t > 0.0:
		return
	if energy < DASH_COST or (air_dash and not is_on_floor()):
		energy_flash = 0.3
		return
	energy -= DASH_COST
	energy_delay = EN_DELAY
	charge = -1.0
	if not is_on_floor():
		air_dash = true
	dash_t = DASH_T
	ghost_t = GHOST_T
	velocity.x = face * DASH_V
	velocity.y = 0.0
	jump_cut = true
	squash = Vector2(1.4, 0.7)


func _attack(dt: float) -> void:
	if Input.is_action_just_pressed("atacar") and dash_t <= 0.0:
		charge = 0.0
	if charge >= 0.0:
		if Input.is_action_pressed("atacar"):
			charge += dt
		else:
			if charge >= CHG_FULL:
				_shoot(true)
			elif shot_cool <= 0.0:
				_shoot(false)
			charge = -1.0


func _shoot(power: bool) -> void:
	shot_cool = SHOT_COOL
	shoot_t = 0.22
	var a := ArrowScript.new()
	a.power = power
	a.face = face
	a.global_position = global_position + Vector2(face * 9, -12)
	get_parent().add_child(a)
	if power:
		velocity.x -= face * 90.0
		squash = Vector2(0.7, 1.2)
		Fx.shake(2.0, 0.12)
		Fx.burst(get_parent(), a.global_position, 8, [Color("7fd6ff"), Color.WHITE], 70.0, 0.0)


func _drop() -> void:
	drop_t = DROP_T
	set_collision_mask_value(2, false)
	buffer = 0.0
	coyote = 0.0
	position.y += 1.0


func _on_platform() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col is CollisionObject2D and (col as CollisionObject2D).get_collision_layer_value(2):
			return true
	return false


## Lo llaman los enemigos. Devuelve true si el golpe entró.
func hurt(from_x: float, dmg: int = 1) -> bool:
	if dead or invuln > 0.0 or ghost_t > 0.0 or stomp_inv > 0.0:
		return false
	hearts = maxi(0, hearts - dmg)
	invuln = INVULN
	hurt_t = 0.3
	charge = -1.0
	dash_t = 0.0
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = -face
	velocity = Vector2(dir * 140.0, -160.0)
	Fx.shake(3.0, 0.2)
	Fx.hitstop(0.06)
	Fx.burst(get_parent(), global_position + Vector2(0, -9), 8, [Color("ff5050"), Color.WHITE], 80.0, 40.0)
	hearts_changed.emit()
	if hearts <= 0:
		dead = true
		set_collision_mask_value(2, false)
		died.emit()
	return true


## Rebote al pisar un slime.
func bounce() -> void:
	var held := Input.is_action_pressed("saltar")
	velocity.y = -JUMP * 1.05 if held else -210.0
	jump_cut = not held
	stomp_inv = 0.22
	double_jumped = false
	air_dash = false
	squash = Vector2(0.8, 1.25)


func _animate(dt: float) -> void:
	sprite.flip_h = face < 0
	var anim := "idle"
	if not is_on_floor():
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 10.0:
		anim = "run"
	var has := func(a: String) -> bool: return sprite.sprite_frames.get_frame_count(a) > 1
	var shoot_frames := sprite.sprite_frames.get_frame_count("shoot")
	if dead and has.call("death"):
		if sprite.animation != "death":
			sprite.play("death")
	elif hurt_t > 0.0 and has.call("hurt"):
		if sprite.animation != "hurt":
			sprite.play("hurt")
	elif dash_t > 0.0 and has.call("dash"):
		if sprite.animation != "dash":
			sprite.play("dash")
	elif shoot_frames >= 5 and charge >= 0.0 and charge >= 0.08:
		# tensando el arco: levanta (0), apunta (1) y queda tirando de la cuerda (2)
		if sprite.animation != "shoot":
			sprite.play("shoot")
		sprite.pause()
		sprite.frame = mini(2, int(charge / CHG_ON * 1.5))
	elif shoot_frames >= 5 and shoot_t > 0.0:
		# suelta: el arco salta para adelante (3) y vuelve (4)
		if sprite.animation != "shoot" or (not sprite.is_playing() and sprite.frame < 3):
			sprite.play("shoot")
			sprite.frame = 3
	elif sprite.animation != anim or (not sprite.is_playing() and anim in ["idle", "run", "fall"]):
		sprite.play(anim)
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 12.0))
	sprite.scale = squash * 0.5
	# parpadeo de invulnerable, fantasma del dash y brillo de carga
	var m := Color.WHITE
	if ghost_t > 0.0:
		m = Color(0.7, 0.9, 1.0, 0.55)
	elif invuln > 0.0 and int(invuln * 20.0) % 2 == 0:
		m.a = 0.3
	elif charge >= CHG_FULL and int(charge * 16.0) % 2 == 0:
		m = Color(1.6, 1.6, 1.8)
	if dead and not has.call("death"):
		m = Color(0.6, 0.6, 0.6)
		sprite.rotation = lerpf(sprite.rotation, PI / 2.0 * -face, dt * 6.0)
	sprite.modulate = m
	if dash_t > 0.0 and Engine.get_physics_frames() % 2 == 0:
		Fx.afterimage(get_parent(), sprite)
