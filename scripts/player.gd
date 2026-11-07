class_name Player
extends CharacterBody2D
## Pip arquero. Valores copiados del juego web (index.html: CHARS.archer, SK, GRAV, DJ).

signal hearts_changed
signal died

## main.gd: puntos, cartas, experiencia (sin tipo para no depender del orden de carga)
var game

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
var bow: Sprite2D  # arco + flecha de la pose de apuntar: quieto mientras el cuerpo respira
var prev_bottom := 0.0
var prev_vy := 0.0
## pies de los últimos cuadros en el aire bajando (para que el pisotón no dependa de un solo cuadro)
var recent_bottoms: Array = []
var stomp_inv := 0.0
var shoot_t := 0.0
var evo := false            # evolucionó a Cazador: dos flechas seguidas y veneno
var venom := false          # veneno prendido (gasta energía)
var cure_used := false      # la poción, una vez por zona
var flash_t := 0.0
var dust_t := 0.0
var skid_t := 0.0
var chg_fx := 0.0           # chispitas que se juntan en el arco mientras carga


func has_card(id: String) -> bool:
	return game != null and game.cards.has(id)


func chg_full() -> float:
	return 0.4 if has_card("carga") else CHG_FULL


func dash_cost() -> float:
	return DASH_COST / 2.0 if has_card("fantasma") else DASH_COST


func dmg(base: int) -> int:
	return base + (1 if has_card("dmg") else 0)


## caja del cuerpo en coordenadas del mundo (para monedas, peligros y el jefe)
func box() -> Rect2:
	return Rect2(global_position.x - 4, global_position.y - 18, 8, 18)


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
	bow = Sprite2D.new()
	bow.texture = load("res://assets/sprites/pip/aim_bow.png")
	bow.centered = true
	bow.offset = Vector2(0, -23)
	bow.scale = Vector2(0.5, 0.5)
	bow.visible = false
	add_child(bow)


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var anims := {"idle": 5.0, "run": 12.0, "jump": 12.0, "fall": 6.0, "shoot": 18.0, "aim": 10.0, "release": 18.0, "hurt": 14.0, "dash": 18.0, "death": 10.0}
	for anim in anims:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, anims[anim])
		sf.set_animation_loop(anim, anim in ["idle", "run", "fall", "aim"])
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
	if game != null and game.state != "play":  # ganó: queda quieto
		dir = 0
		jump_pressed = false
		jump_held = false
		down = false

	_timers(dt)
	_special(dt, Input.is_action_just_pressed("especial") and (game == null or game.state == "play"))
	if evo:
		_venom_step(dt, Input.is_action_just_pressed("poder"))

	# saltar corta la carga del arco y el dash
	if jump_pressed and coyote > 0.0:
		charge = -1.0
		dash_t = 0.0

	var dashing := dash_t > 0.0
	var slow := 0.0 if charge >= CHG_ON else 1.0  # cargando no se mueve
	var top := SPEED * slow * (1.15 if has_card("veloz") else 1.0)

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
			Snd.play("salto")
			Fx.dust(get_parent(), global_position, 4, 26.0, 5.0, 1.6)
	elif buffer > 0.0 and not is_on_floor() and not double_jumped and not dashing:
		double_jumped = true
		velocity.y = -JUMP * DJ
		buffer = 0.0
		jump_cut = false
		charge = -1.0
		squash = Vector2(0.75, 1.3)
		Snd.play("salto", {"rate": 1.35})
		# anillo de aire aplastado bajo los pies y unas estelas que bajan
		Fx.ring(get_parent(), global_position + Vector2(0, 1), Pal.C, 0.0, 9.0, 0.3, 0.24)
		Fx.ring(get_parent(), global_position + Vector2(0, 3), Pal.W, -0.04, 6.0, 0.3, 0.2)
		for i in 4:
			var a := PI * (0.25 + 0.5 * i / 3.0)
			Fx.streak(get_parent(), global_position + Vector2(0, 1), Vector2(cos(a) * 70.0, sin(a) * 90.0), 0.16, Pal.W if i % 2 == 1 else Pal.C, 4.0)
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
	prev_vy = velocity.y
	recent_bottoms.push_front(prev_bottom if (not was_floor and velocity.y > 0.0) else 1e9)
	if recent_bottoms.size() > 4:
		recent_bottoms.pop_back()
	move_and_slide()
	if is_on_floor():
		double_jumped = false
		air_dash = false
		if not was_floor and fall_speed > 140.0:
			var k := minf(1.0, (fall_speed - 140.0) / 130.0)
			squash = Vector2(1.1 + 0.4 * k, 0.92 - 0.32 * k)
			Fx.dust(get_parent(), global_position, 2 + roundi(4 * k), 22.0 + 30.0 * k, 3.0, 1.4 + 1.0 * k)
			if k > 0.55:
				Fx.shock(get_parent(), global_position, Pal.S, 10.0 + 6.0 * k, 0.25)
				Fx.chunks(get_parent(), global_position, 2, [Pal.S, Pal.SS], 40.0, 30.0, global_position.y)
			Snd.play("aterrizar", {"vol": 0.5 + 0.5 * k})
		# polvito al correr (al pisar) y derrape al dar la vuelta corriendo
		if absf(velocity.x) > 60.0:
			dust_t -= dt
			if dust_t <= 0.0:
				dust_t = 0.16
				Fx.dust(get_parent(), global_position + Vector2(-face * 3, 0), 1, 14.0, 7.0, 1.2, Pal.S, -signf(velocity.x))
		if dir != 0 and signf(velocity.x) == -dir and absf(velocity.x) > 50.0:
			skid_t -= dt
			if skid_t <= 0.0:
				skid_t = 0.05
				Fx.dust(get_parent(), global_position + Vector2(signf(velocity.x) * 3.0, 0), 1, 20.0, 5.0, 1.5, Pal.S, signf(velocity.x))
				squash = Vector2(1.08, 0.94)

	_attack(dt)
	_animate(dt)


func _timers(dt: float) -> void:
	shot_cool -= dt
	stomp_inv -= dt
	shoot_t -= dt
	flash_t -= dt
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
		energy = minf(EN_MAX, energy + EN_REGEN * (1.6 if has_card("energia") else 1.0) * dt)


func _special(_dt: float, pressed: bool) -> void:
	if not pressed or dash_t > 0.0:
		return
	if energy < dash_cost() or (air_dash and not is_on_floor()):
		no_energy()
		return
	energy -= dash_cost()
	energy_delay = EN_DELAY
	charge = -1.0
	if not is_on_floor():
		air_dash = true
	dash_t = DASH_T
	ghost_t = GHOST_T
	velocity.x = face * DASH_V
	velocity.y = 0.0
	jump_cut = true
	squash = Vector2(1.35, 0.75)
	Snd.play("dash")
	Fx.kick(Vector2(face, 0), 1.0)
	Fx.ring(get_parent(), global_position + Vector2(-face * 4, -8), Pal.C, 0.0, 8.0, 1.0, 0.2)
	if is_on_floor():
		Fx.dust(get_parent(), global_position + Vector2(-face * 3, 0), 3, 30.0, 6.0, 1.8, Pal.S, -face)


func no_energy() -> void:
	if energy_flash > 0.25:
		return
	energy_flash = 0.45
	Snd.play("menu", {"rate": 0.55, "vol": 0.5, "vary": false})


## Veneno del Cazador: el botón de poder lo prende y apaga; mientras está prendido gasta energía.
func _venom_step(dt: float, pressed: bool) -> void:
	if pressed:
		if venom:
			venom = false
			Snd.play("menu", {"rate": 0.8, "vol": 0.5, "vary": false})
		elif energy < 10.0:
			no_energy()
		else:
			venom = true
			Snd.play("baba", {"rate": 0.8})
			Snd.play("poder", {"rate": 1.4, "vol": 0.5})
			Fx.popup(get_parent(), global_position + Vector2(0, -24), "VENENO", Pal.L)
			squash = Vector2(0.85, 1.15)
			Fx.burst(get_parent(), global_position + Vector2(0, -9), 10, [Pal.L, Pal.G, Pal.W], 60.0, 20.0, 0.35, 0.0)
			Fx.ring(get_parent(), global_position + Vector2(0, -9), Pal.L, 0.0, 12.0, 1.0, 0.3)
	if venom:
		energy -= 16.0 * dt
		energy_delay = maxf(energy_delay, EN_DELAY)
		if energy <= 0.0:
			energy = 0.0
			venom = false
			energy_delay = 1.2
			Snd.play("menu", {"rate": 0.55, "vol": 0.5, "vary": false})


func _attack(dt: float) -> void:
	if game != null and game.state != "play":
		charge = -1.0
		return
	if Input.is_action_just_pressed("atacar") and dash_t <= 0.0:
		charge = 0.0
	if charge >= 0.0:
		if Input.is_action_pressed("atacar"):
			var was := charge
			charge += dt
			if was < CHG_ON and charge >= CHG_ON:
				Snd.play("menu", {"rate": 0.75, "vol": 0.3, "vary": false})
			var bow_at := global_position + Vector2(face * 9, -11)
			if was < chg_full() and charge >= chg_full():
				Snd.play("cargado", {"vary": false})
				Fx.twinkle(get_parent(), bow_at, Pal.C, 6.0, 0.3)
				Fx.ring(get_parent(), bow_at, Pal.C, 0.0, 9.0, 1.0, 0.22)
			# chispitas que se juntan en el arco mientras tensa; cargado, alguna que se escapa
			if charge >= CHG_ON:
				chg_fx -= dt
				if chg_fx <= 0.0:
					var full := charge >= chg_full()
					chg_fx = 0.09 if full else 0.035
					if full:
						Fx.part(get_parent(), bow_at + Vector2(randf_range(-2, 2), randf_range(-3, 3)), Vector2(randf_range(-8, 8), -22), -30.0, 0.35, Pal.C)
					else:
						Fx.converge(get_parent(), bow_at, 9.0 + randf() * 5.0, Pal.C if randf() < 0.6 else Pal.W, 0.18)
		else:
			if charge >= chg_full():
				_shoot(true)
			elif shot_cool <= 0.0 and _flying_arrows() < 4:
				_shoot(false)
			charge = -1.0


func _flying_arrows() -> int:
	var n := 0
	for a in get_tree().get_nodes_in_group("flechas"):
		if not a.stuck:
			n += 1
	return n


func _arrow(power: bool, vy: float = 0.0, delay: float = 0.0) -> Node:
	var a := ArrowScript.new()
	a.power = power
	a.face = face
	a.vy0 = vy
	a.delay = delay
	a.venom = venom
	a.dmg = dmg(3 if power else 1)
	a.global_position = global_position + Vector2(face * 9, -11)
	get_parent().add_child(a)
	return a


func _shoot(power: bool) -> void:
	shot_cool = SHOT_COOL * (1.5 if evo and not power else 1.0)
	# lo que dura la animación de soltar (si no hay, un ratito)
	var rel := sprite.sprite_frames.get_frame_count("release")
	shoot_t = rel / sprite.sprite_frames.get_animation_speed("release") if rel > 1 else 0.22
	if sprite.animation == "release":  # disparos seguidos: vuelve a arrancar el retroceso
		sprite.frame = 0
		sprite.play("release")
	var a := _arrow(power)
	if not power:
		squash = Vector2(1.12, 0.92)  # pequeño retroceso al soltar
		velocity.x -= face * 34.0
		Snd.play("disparo")
		Fx.kick(Vector2(-face, 0), 0.6)
		Fx.twinkle(get_parent(), a.global_position + Vector2(face * 2, 0), Pal.W, 2.5, 0.12)
		Fx.streak(get_parent(), a.global_position, Vector2(face * 120.0, -15.0), 0.1, Pal.W, 3.0)
		Fx.streak(get_parent(), a.global_position, Vector2(face * 120.0, 15.0), 0.1, Pal.W, 3.0)
		if evo:  # la ballesta del Cazador tira dos seguidas
			_arrow(false, 0.0, 0.09)
			Snd.play("disparo", {"delay": 0.09, "rate": 1.1})
	if power:
		if has_card("triple"):
			_arrow(true, -55.0)
			_arrow(true, 40.0)
		velocity.x -= face * 90.0
		squash = Vector2(0.7, 1.2)
		Snd.play("poder")
		Snd.play("disparo", {"rate": 0.7, "vol": 0.8})
		Fx.shake(2.0, 0.12)
		Fx.kick(Vector2(-face, 0), 1.8)
		Fx.hit(get_parent(), a.global_position + Vector2(face * 2, 0), Vector2(face, 0), Pal.C, true)
		Fx.ring(get_parent(), a.global_position, Pal.C, 0.0, 10.0, 1.0, 0.25)
		if is_on_floor():
			Fx.dust(get_parent(), global_position, 3, 30.0, 4.0, 1.6, Pal.S, -face)


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
func hurt(from_x: float, amount: int = 1) -> bool:
	if dead or invuln > 0.0 or ghost_t > 0.0 or stomp_inv > 0.0:
		return false
	if game != null and game.state != "play":
		return false
	hearts = maxi(0, hearts - amount)
	invuln = 1.4
	hurt_t = 0.3
	charge = -1.0
	dash_t = 0.0
	flash_t = 0.09
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = -face
	velocity = Vector2(dir * 140.0, -170.0)
	squash = Vector2(1.3, 0.75)
	Snd.play("dano")
	Fx.hitstop(0.09)
	Fx.shake(5.0, 0.28)
	Fx.flash_red = 0.18
	Fx.kick(Vector2(dir, 0), 2.5)
	Fx.hit(get_parent(), global_position + Vector2(-dir * 3.0, -10), Vector2(dir, -0.3), Pal.R, true)
	Fx.burst(get_parent(), global_position + Vector2(0, -9), 8, [Pal.R, Pal.O, Pal.W], 80.0, 40.0, 0.45, 220.0)
	hearts_changed.emit()
	if hearts <= 0:
		dead = true
		set_collision_mask_value(2, false)
		died.emit()
	else:
		_try_cure()
	return true


## Carta "poción": una vez por zona, al bajar de la mitad de la vida, cura dos corazones.
func _try_cure() -> void:
	if not has_card("cura") or cure_used or hearts <= 0 or hearts > max_hearts / 2.0:
		return
	hearts = mini(max_hearts, hearts + 2)
	cure_used = true
	hearts_changed.emit()
	Snd.play("moneda", {"rate": 0.7, "vary": false})
	Snd.play("oleada", {"rate": 1.6, "vol": 0.5, "vary": false})
	Fx.popup(get_parent(), global_position + Vector2(0, -24), "¡POCIÓN!", Pal.L, true)
	Fx.burst(get_parent(), global_position + Vector2(0, -9), 14, [Pal.L, Pal.G, Pal.W], 60.0, 40.0, 0.6, 60.0)
	Fx.ring(get_parent(), global_position + Vector2(0, -9), Pal.L, 0.0, 16.0)
	for i in 6:
		Fx.part(get_parent(), global_position + Vector2(randf_range(-6, 6), -randf_range(2, 16)), Vector2(0, -25), -20.0, 0.6, Pal.L)


## ¡Evolución! Ahora es Cazador: vida llena, dos flechas por disparo y veneno con el botón de poder.
func evolve() -> void:
	evo = true
	hearts = max_hearts
	hearts_changed.emit()
	invuln = maxf(invuln, 1.0)
	charge = -1.0
	flash_t = 0.2
	squash = Vector2(0.6, 1.5)
	Fx.popup(get_parent(), global_position + Vector2(0, -26), "CAZADOR", Pal.Y, true)
	Snd.play("oleada", {"vary": false})
	Snd.play("critico", {"rate": 1.2, "vary": false})
	Snd.play("oleada", {"delay": 0.25, "rate": 1.26, "vary": false})
	Fx.slowmo = maxf(Fx.slowmo, 0.6)
	Fx.hitstop(0.12)
	Fx.shake(3.0, 0.3)
	Fx.burst(get_parent(), global_position + Vector2(0, -9), 30, [Pal.Y, Pal.W, Pal.C, Pal.O], 140.0, 60.0, 0.9, 60.0)
	for i in 3:
		Fx.ring(get_parent(), global_position + Vector2(0, -9), [Pal.W, Pal.Y, Pal.C][i], -0.1 * i, 26.0 + 6.0 * i)
	Fx.shock(get_parent(), global_position, Pal.Y, 30.0, 0.45)
	for i in 5:
		Fx.twinkle(get_parent(), global_position + Vector2(randf_range(-12, 12), -randf_range(4, 26)), Pal.Y, randf_range(3.0, 5.0), 0.3 + 0.06 * i)


## Rebote al pisarle el yelmo al jefe.
func boss_bounce() -> void:
	var held := Input.is_action_pressed("saltar")
	velocity.y = -JUMP * 1.1 if held else -260.0
	jump_cut = not held
	stomp_inv = 0.35
	recent_bottoms.clear()
	double_jumped = false
	air_dash = false
	squash = Vector2(0.8, 1.25)
	Snd.play("pisoton", {"rate": 0.8})
	Fx.ring(get_parent(), global_position, Pal.W, 0.0, 8.0, 0.35, 0.2)


## Rebote al pisar un slime.
func bounce() -> void:
	var held := Input.is_action_pressed("saltar")
	velocity.y = -JUMP * 1.05 if held else -210.0
	jump_cut = not held
	stomp_inv = 0.22
	recent_bottoms.clear()
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
	if dead and has.call("death"):
		if sprite.animation != "death":
			sprite.play("death")
	elif hurt_t > 0.0 and has.call("hurt"):
		if sprite.animation != "hurt":
			sprite.play("hurt")
	elif dash_t > 0.0 and has.call("dash"):
		if sprite.animation != "dash":
			sprite.play("dash")
	elif charge >= 0.08 and has.call("shoot"):
		# tensa el arco (shoot, una vez) y después queda apuntando con balanceo y capa al viento (aim, en loop)
		if sprite.animation == "aim":
			pass
		elif sprite.animation != "shoot":
			sprite.play("shoot")
		elif not sprite.is_playing() and has.call("aim"):
			sprite.play("aim")
	elif shoot_t > 0.0 and has.call("release"):
		# suelta: retroceso del arco y la capa que vuelve
		if sprite.animation != "release":
			sprite.play("release")
	elif sprite.animation != anim or (not sprite.is_playing() and anim in ["idle", "run", "fall"]):
		sprite.play(anim)
	# el ciclo de correr va con la velocidad (sin patinar al arrancar o frenar)
	sprite.speed_scale = clampf(absf(velocity.x) / SPEED, 0.55, 1.3) if sprite.animation == "run" else 1.0
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 12.0))
	# respiración al apuntar: el cuerpo sube y baja y se ensancha apenas, además de la capa del loop
	var breath := Vector2.ONE
	sprite.offset.y = -23.0
	if sprite.animation == "aim":
		var b := sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.9)
		breath = Vector2(1.0 + 0.015 * b, 1.0 - 0.025 * b)
		sprite.offset.y = -23.0 + roundf(b)
	sprite.scale = squash * breath * 0.5
	# el arco y la flecha no respiran: quedan clavados para dar tensión
	bow.visible = sprite.animation == "aim"
	bow.flip_h = sprite.flip_h
	# parpadeo de invulnerable, fantasma del dash y brillo de carga
	var m := Color.WHITE
	if ghost_t > 0.0:
		m = Color(0.7, 0.9, 1.0, 0.55)
	elif invuln > 0.0 and int(invuln * 20.0) % 2 == 0:
		m.a = 0.3
	elif charge >= chg_full() and int(charge * 16.0) % 2 == 0:
		m = Color(1.6, 1.6, 1.8)
	# destello: la silueta entera en blanco (como el pixel art de antes), no un brillo lavado
	var white := flash_t > 0.0
	if white:
		m = Color.WHITE
	sprite.material = Fx.silhouette(Color.WHITE) if white else null
	bow.material = sprite.material
	if dead and not has.call("death"):
		m = Color(0.6, 0.6, 0.6)
		sprite.rotation = lerpf(sprite.rotation, PI / 2.0 * -face, dt * 6.0)
	sprite.modulate = m
	bow.modulate = m
	if dash_t > 0.0:
		var fr := Engine.get_physics_frames()
		if fr % 2 == 0:
			Fx.afterimage(get_parent(), sprite, Pal.C if fr % 4 == 0 else Pal.B)
		Fx.streak(get_parent(), global_position + Vector2(-face * randf_range(2, 8), -randf_range(2, 17)),
			Vector2(-face * 200.0, 0), 0.12, Pal.W if randf() < 0.4 else Pal.C, 7.0)
	# Cazador: chispitas doradas de vez en cuando; con veneno, gotitas verdes
	if evo and not dead and randf() < 0.08:
		Fx.part(get_parent(), global_position + Vector2(randf_range(-5, 5), -randf_range(4, 18)), Vector2(0, -14), -10.0, 0.4, Pal.Y if randf() < 0.6 else Pal.W)
	if venom and not dead and randf() < 0.3:
		Fx.part(get_parent(), global_position + Vector2(face * 8 + randf_range(-2, 2), -11), Vector2(0, -18), -10.0, 0.4, Pal.L if randf() < 0.5 else Pal.G)
