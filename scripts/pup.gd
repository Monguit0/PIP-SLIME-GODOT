extends "res://scripts/forest_mob.gd"
## Cachorro de lobo del Bosque Oscuro (el del juego web): corre hacia el héroe y, cuando lo tiene cerca,
## se agazapa un instante y le salta encima.
## Manejado por una persona (modo Villano): X salta a morder, Shift es el turbo.

const POUNCE_VX := 250.0
const POUNCE_VY := 110.0
const WARN := 0.22

var warn := 0.0
var pouncing := false
var land_t := 0.0
var air_jump := true        # le queda el segundo salto


func _setup() -> void:
	kind = "pup"
	dir_path = "res://assets/sprites/bosque/lobito/"
	anims = ["idle", "run", "pounce", "death"]
	foot_y = 55.0
	draw_scale = 0.36
	body_w = 16.0
	body_h = 13.0
	base_hp = 2
	walk_speed = 66.0
	ctrl_speed = 84.0
	jump_v = 230.0
	mob_title = "CACHORRO DE LOBO"
	goo = [Color("41586a"), Color("9ebcc1"), Color("1d2335")]
	top_mark = -24.0


func mob_hint() -> String:
	return "X: SALTO A MORDER · SHIFT: TURBO · DOBLE SALTO"


func _interrupt() -> void:
	warn = 0.0
	pouncing = false


func _leap() -> void:
	pouncing = true
	velocity = Vector2(face * POUNCE_VX, -POUNCE_VY)
	squash = Vector2(1.4, 0.7)
	Snd.play("salto", {"rate": 1.9, "vol": 0.6})
	Fx.dust(get_parent(), global_position, 3, 26.0, 6.0, 1.4, Pal.S)


func _step(dt: float) -> void:
	var dir := 0.0
	var top := walk_speed
	land_t -= dt
	if pouncing:
		# en el aire sigue de largo; al tocar el piso frena
		dir = face
		top = POUNCE_VX
		if is_on_floor() and velocity.y >= 0.0:
			pouncing = false
			land_t = 0.12
			cool = maxf(cool, 0.5)
			squash = Vector2(1.25, 0.8)
	elif warn > 0.0:
		warn -= dt
		if warn <= 0.0:
			_leap()
			dir = face
			top = POUNCE_VX
	elif ctrl:
		var grounded := is_on_floor()
		dir = ctrl_dir()
		if grounded:
			air_jump = true
		elif air_jump and playing() and stun <= 0.0 and Ctl.tap(dev(), "saltar"):
			# el segundo salto, en el aire
			air_jump = false
			velocity.y = -jump_v * 0.92
			squash = Vector2(0.7, 1.35)
			Snd.play("salto", {"rate": 1.7})
			Fx.dust(get_parent(), global_position, 3, 22.0, 6.0, 1.4, Pal.S)
		var on: bool = turbo.step(self, dt, stun <= 0.0 and Ctl.down(dev(), "especial") and playing(), face, Color("9ebcc1"), 8.0)
		top = ctrl_speed * (Turbo.MUL if on else 1.0)
		if playing() and stun <= 0.0 and Ctl.tap(dev(), "atacar") and cool <= 0.0 and is_on_floor():
			cool = 0.8
			_leap()
			dir = face
			top = POUNCE_VX
	elif hero != null and not hero.dead and stun <= 0.0:
		var dx := hero.global_position.x - global_position.x
		var dy := hero.global_position.y - global_position.y
		face = signf(dx) if dx != 0.0 else face
		if is_on_floor() and cool <= 0.0 and absf(dx) < 44.0 and absf(dy) < 26.0:
			warn = WARN
			cool = 1.3 + randf() * 0.6
			Snd.play("alerta", {"rate": 1.4, "vol": 0.25})
		elif absf(dx) < 240.0 and absf(dx) > 8.0:
			dir = signf(dx)
	walk(dir, top, dt)


func _anim() -> void:
	if warn > 0.0:
		sprite.texture = frame("pounce", 0 if warn > WARN * 0.5 else 1)
	elif pouncing:
		sprite.texture = frame("pounce", 3 if velocity.y < 30.0 else 4)
	elif land_t > 0.0:
		sprite.texture = frame("pounce", 5)
	elif absf(velocity.x) > 10.0 and is_on_floor():
		sprite.texture = frame("run", int(anim_t * (16.0 if turbo.on else 12.0)) % count("run"))
	else:
		sprite.texture = frame("idle", int(anim_t * 5.0) % count("idle"))


func look() -> void:
	super.look()
	if warn > 0.0:
		sprite.scale *= Vector2(1.1, 0.85)


func _draw_extra() -> void:
	if ctrl:
		turbo.draw_bar(self)
