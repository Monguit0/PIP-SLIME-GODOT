class_name Player
extends CharacterBody2D
## Los héroes: Pip arquero, el caballero, el bárbaro y el mago. Valores copiados del juego web
## (index.html: CHARS, SK, GRAV, DJ, skillStep, chargeStep, slashBoxOf, hurt).

signal hearts_changed
signal died
signal hurt_by(src)   # le pegaron de verdad (no frenó el escudo): quién fue

## main.gd: puntos, cartas, experiencia (sin tipo para no depender del orden de carga)
var game

const GRAV := 900.0
const FALL_MUL := 1.25
const MAX_FALL := 270.0
const SPEED := 92.0          # los del arquero; cada héroe tiene los suyos en HEROES
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

# escudo del caballero y furia del bárbaro (SK del original)
const SH_MIN := 12.0         # energía mínima para levantarlo
const SH_ON := 6.0           # lo que cuesta levantarlo
const SH_DRAIN := 28.0       # lo que gasta por segundo
const SH_BLOCK := 24.0       # lo que gasta cada golpe parado
const PARRY := 0.22          # recién levantado: el golpe se devuelve
const PARRY_R := 36.0        # el parry empuja a los que estén cerca
const PARRY_INV := 1.5
const RAGE := 70.0
const RAGE_T := 5.0
const SPIN_GAP := 0.2        # el giro del hacha pega cada 0,2 s
const SPIN_HIT := 0.12
const BIG_HIT := 0.12        # el espadazo llega al piso (el cuadro del impacto)
const CHOP_ARC := 2.0 / 11.0  # el hachazo del bárbaro: a esta altura de la animación empieza a bajar el hacha...
const CHOP_K := 4.0 / 11.0    # ...y a esta muerde el piso
const SPIN_HITS := 2          # golpes del giro por cada vuelta de su animación (dos barridos dibujados)

# mago: bola de fuego (SK.fire) y, de Nigromante, los esqueletos aliados (SK.summon)
const FIRE_COST := 30.0
const FIRE_WIND := 0.07       # del botón a que sale la bola: lo que tarda en estirar el bastón
const SUMMON_COST := 50.0
const SLAM_K := 0.45          # el bastonazo cargado toca el piso a esta altura de su animación
const BLINK_T := 0.3          # el destello del doble salto del mago
const TWIRL_T := 0.34         # el giro en tirabuzón del doble salto del mago
const HANG := 45.0            # arriba de todo del salto el mago queda un instante flotando (por debajo de esta velocidad)

const BOT_SPEED := 0.62         # los héroes del bot avanzan más despacio que una persona: te dan tiempo de pelear

const ArrowScript := preload("res://scripts/arrow.gd")
const FireballScript := preload("res://scripts/fireball.gd")
const AllyScript := preload("res://scripts/ally.gd")
const SPR := "res://assets/sprites/"
## hearts, speed, jump y cool de CHARS; dir y evo_dir son las carpetas de los cuadros (PixelLab);
## feet: fila de abajo de los pies en el lienzo (el sprite se dibuja con los pies en el origen);
## fps: animaciones que van a otra velocidad que la común (el bárbaro tiene el doble de cuadros en sus golpes)
const HEROES := {
	"archer": {"name": "ARQUERO", "evo": "CAZADOR", "hearts": 3, "speed": 92.0, "jump": 268.0, "cool": 0.25,
		"dir": "pip", "evo_dir": "pip_cazador", "feet": 55.0},
	"knight": {"name": "CABALLERO", "evo": "PALADÍN", "hearts": 4, "speed": 84.0, "jump": 262.0, "cool": 0.34,
		"dir": "caballero", "evo_dir": "paladin", "feet": 57.0},
	"barb": {"name": "BÁRBARO", "evo": "WARLORD", "hearts": 4, "speed": 94.0, "jump": 262.0, "cool": 0.46,
		"dir": "barbaro", "evo_dir": "warlord", "feet": 57.0, "fps": {"attack": 32.0, "spin": 30.0}},
	"mage": {"name": "MAGO", "evo": "NIGROMANTE", "hearts": 3, "speed": 88.0, "jump": 264.0, "cool": 0.4,
		"dir": "mago", "evo_dir": "nigromante", "feet": 55.0, "fps": {"attack": 26.0, "big": 22.0, "run": 15.0}},
}
const KINDS := ["archer", "knight", "barb", "mage"]
const FLIP_T := 0.38          # lo que dura la vuelta carnero del bárbaro en el doble salto
const FLIP_C := 14.0          # alto del centro del cuerpo: la vuelta gira alrededor de ahí, no de los pies
## las animaciones de los héroes y sus cuadros por segundo (cada héroe puede cambiarlos con "fps")
const ANIMS := {"idle": 5.0, "run": 12.0, "jump": 12.0, "fall": 6.0, "shoot": 18.0, "aim": 10.0, "release": 18.0, "hurt": 14.0, "dash": 18.0, "death": 10.0,
	"attack": 24.0, "charge": 16.0, "big": 14.0, "spin": 40.0, "shield": 18.0, "fury": 12.0,
	"charge_hold": 8.0, "charge_walk": 10.0, "flourish": 11.0, "land": 14.0, "cast": 24.0, "summon": 14.0,
	"apex": 8.0, "twirl": 16.0}

## qué héroe es (main.gd lo pone antes de agregarlo; en el título se cambia con set_kind)
var kind := "archer"
var speed := SPEED
var jump_v := JUMP
var cool := SHOT_COOL

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
var flip_t := 0.0             # bárbaro: la vuelta carnero del doble salto (cuenta hacia cero)
var evo_frames: SpriteFrames  # el diseño del Cazador (se cambia al evolucionar)
var venom := false          # veneno prendido (gasta energía)
var cure_used := false      # la poción, una vez por zona
var flash_t := 0.0
var dust_t := 0.0
var skid_t := 0.0
var idle_t := 0.0            # cuánto lleva quieto (el caballero hace un floreo con la espada)
var flourish_t := 0.0
var step_fr := -1            # último cuadro de la carrera que sonó como pisada
var land_t := 0.0            # recién aterrizó: se agacha un instante
var chg_fx := 0.0           # chispitas que se juntan en el arco mientras carga
# cuerpo a cuerpo (caballero y bárbaro)
var swing_t := 9.0           # desde el último golpe
var swing_id := 0
var big := false             # espadazo cargado del caballero
var big_fx := true           # ya llegó al piso el espadazo (el impacto va una vez por golpe)
var chop_fx := true          # lo mismo para el hachazo del bárbaro
var chop_arc := true         # ya salió la media luna del hachazo
var spin := false            # giro del hacha del bárbaro
var spin_n := 2
var atk_buf := 0.0
var hit_keys := {}           # a quién ya le pegó este golpe (id del nodo -> golpe)
var shield := false
var shield_t := 0.0
var block_t := 0.0
var parry_inv := 0.0
var heal_at := -9.0
var rage_t := 0.0
var rage_mul := 1.0
var fury_t := 0.0            # lo que dura el rugido de la furia
# mago
var cast_t := 0.0            # lo que dura el gesto de tirar la bola
var cast_wind := -1.0        # cuenta hasta que la bola sale (-1: no hay ninguna por salir)
var summon_t := 0.0          # el gesto de invocar del Nigromante
var blink_t := 0.0           # destello del doble salto
var gem_t := 0.0             # brasas que suelta la gema del bastón
var twirl_t := 0.0           # girando en el aire (doble salto y al rebotar en un enemigo)
var apex_fx := false         # ya salió el destello de arriba de todo del salto
# modo Villano: a este héroe lo maneja un bot (hero_bot.gd), que "aprieta" las acciones por él
var bot := false
var brain
var inp := {}
var inp_prev := {}
var base_oy := -23.0         # dónde va el lienzo para que los pies queden en el origen


func has_card(id: String) -> bool:
	return game != null and game.cards.has(id)


func chg_full() -> float:
	return 0.4 if has_card("carga") else CHG_FULL


func dash_cost() -> float:
	return DASH_COST / 2.0 if has_card("fantasma") else DASH_COST


func melee() -> bool:
	return kind != "archer"


## lo que cuesta el especial de cada uno (las marcas de la barra de energía)
## Las acciones del héroe: del teclado o el joystick, o las que decide el bot.
func _down(a: String) -> bool:
	return bool(inp.get(a, false)) if bot else Input.is_action_pressed(a)


func _tap(a: String) -> bool:
	return (bool(inp.get(a, false)) and not bool(inp_prev.get(a, false))) if bot else Input.is_action_just_pressed(a)


func special_cost() -> float:
	match kind:
		"knight":
			return SH_MIN
		"barb":
			return RAGE
		"mage":
			return FIRE_COST
	return dash_cost()


## daño de un golpe con la carta y la furia (heroDmg del original)
func dmg(base: int) -> int:
	return maxi(1, roundi((base + (1 if has_card("dmg") else 0)) * (rage_mul if rage_t > 0.0 else 1.0)))


## la furia del Warlord acelera los golpes
func haste() -> float:
	return 0.6 if evo and kind == "barb" and rage_t > 0.0 else 1.0


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
	sprite.centered = true
	sprite.scale = Vector2(0.5, 0.5) # píxeles HD: se dibuja a la mitad, como en el original
	add_child(sprite)
	bow = Sprite2D.new()
	bow.centered = true
	bow.scale = Vector2(0.5, 0.5)
	bow.visible = false
	add_child(bow)
	set_kind(kind)


## Cambia de héroe (en el título se elige con izquierda y derecha): cuadros, vida y números de CHARS.
func set_kind(k: String) -> void:
	kind = k if HEROES.has(k) else "archer"
	var h: Dictionary = HEROES[kind]
	speed = h.speed
	jump_v = h.jump
	cool = h.cool
	max_hearts = h.hearts
	hearts = max_hearts
	var dir: String = SPR + h.dir + "/"
	var edir: String = SPR + h.evo_dir + "/"
	var fps: Dictionary = h.get("fps", {})
	sprite.sprite_frames = _build_frames(dir, fps)
	evo_frames = _build_frames(edir, fps) if ResourceLoader.exists(edir + "idle/frame_000.png") else null
	sprite.play("idle")
	if ResourceLoader.exists(dir + "aim_bow.png"):
		bow.texture = load(dir + "aim_bow.png")
	shield = false
	rage_t = 0.0
	charge = -1.0
	cast_t = 0.0
	cast_wind = -1.0
	summon_t = 0.0
	_place_sprite()
	hearts_changed.emit()


## los pies en el origen: el lienzo de cada héroe es distinto (Pip 64, caballero y bárbaro 68)
func _place_sprite() -> void:
	var tex := sprite.sprite_frames.get_frame_texture("idle", 0)
	var hgt := float(tex.get_height()) if tex != null else 64.0
	base_oy = -(float(HEROES[kind].feet) - hgt / 2.0)
	sprite.offset = Vector2(0, base_oy)
	bow.offset = Vector2(0, base_oy)


## Los cuadros de los otros héroes (y sus evoluciones), para cargarlos en segundo plano desde el título:
## así cambiar de héroe la primera vez no frena el juego.
static func asset_paths(skip: String = "") -> Array:
	var out: Array = []
	for k in KINDS:
		if k == skip:
			continue
		for d in [HEROES[k].dir, HEROES[k].evo_dir]:
			for anim in ANIMS:
				var i := 0
				while ResourceLoader.exists("%s%s/%s/frame_%03d.png" % [SPR, d, anim, i]):
					out.append("%s%s/%s/frame_%03d.png" % [SPR, d, anim, i])
					i += 1
	return out


## Los SpriteFrames ya armados, por carpeta: quedan entre partidas, así que cada héroe se arma una sola vez.
static var _frames_cache := {}

func _build_frames(dir: String, fps: Dictionary = {}) -> SpriteFrames:
	if _frames_cache.has(dir):
		return _frames_cache[dir]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var anims := ANIMS
	for anim in anims:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, fps.get(anim, anims[anim]))
		sf.set_animation_loop(anim, anim in ["idle", "run", "fall", "aim", "spin", "charge_hold", "charge_walk"])
		var i := 0
		while true:
			var path := "%s%s/frame_%03d.png" % [dir, anim, i]
			if not ResourceLoader.exists(path):
				break
			sf.add_frame(anim, load(path))
			i += 1
	# si falta alguna animación, usa la quieta; si no hay nada, un muñequito de colores
	var still: Texture2D = null
	if ResourceLoader.exists(dir + "east.png"):
		still = load(dir + "east.png")
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
	_frames_cache[dir] = sf
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

	if bot:
		inp_prev = inp.duplicate()
		if brain != null:
			brain.think(self, dt)
	var dir := int(_down("derecha")) - int(_down("izquierda"))
	var jump_pressed := _tap("saltar")
	var jump_held := _down("saltar")
	var down := _down("abajo")
	if game != null and game.state != "play":  # ganó: queda quieto
		dir = 0
		jump_pressed = false
		jump_held = false
		down = false

	_timers(dt)
	var playing: bool = game == null or game.state == "play"
	match kind:
		"knight":
			_shield_step(dt, _down("especial") and playing, _tap("especial") and playing)
		"barb":
			_fury_step(dt, _tap("especial") and playing)
		"mage":
			_cast_step(dt, _tap("especial") and playing)
			if evo:
				_necro_step(_tap("poder") and playing)
		_:
			_special(dt, _tap("especial") and playing)
			if evo:
				_venom_step(dt, _tap("poder"))

	# saltar corta la carga del arco y el dash (el caballero y el bárbaro siguen cargando en el aire)
	if jump_pressed and coyote > 0.0:
		if not melee():
			charge = -1.0
		dash_t = 0.0

	var dashing := dash_t > 0.0
	# el arquero cargando no se mueve; el caballero y el bárbaro van más lento, y con el escudo a la mitad
	var slow := 1.0
	if shield:
		slow = 0.5
	elif charge >= CHG_ON:
		slow = 0.6 if melee() else 0.0
	var top := speed * slow * (1.15 if has_card("veloz") else 1.0) * (BOT_SPEED if bot else 1.0)

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
			velocity.y = -jump_v
			coyote = 0.0
			buffer = 0.0
			jump_cut = false
			squash = Vector2(0.7, 1.35)
			Snd.play("salto")
			Fx.dust(get_parent(), global_position, 4, 26.0, 5.0, 1.6)
			# despegue: un aro de aire aplastado en el piso, el polvo que patea hacia atrás si viene corriendo
			# y unas líneas que quedan abajo mientras sube
			Fx.shock(get_parent(), global_position, Pal.S, 9.0, 0.2)
			if absf(velocity.x) > 30.0:
				Fx.dust(get_parent(), global_position + Vector2(-signf(velocity.x) * 3.0, 0), 2, 36.0, 4.0, 1.5, Pal.S, -signf(velocity.x))
			for i in 3:
				Fx.streak(get_parent(), global_position + Vector2(-4.0 + 4.0 * i, -1.0 - 3.0 * (i % 2)), Vector2(0, 90.0), 0.12, Pal.W, 5.0)
			if kind == "mage":
				# el mago se impulsa con magia: un aro de su color bajo los pies y brasas que suben con él
				squash = Vector2(0.68, 1.4)
				Fx.ring(get_parent(), global_position + Vector2(0, 1), _mage_col(2), 0.0, 10.0, 0.3, 0.22)
				for i in 5:
					Fx.part(get_parent(), global_position + Vector2(randf_range(-6, 6), -randf_range(0, 6)), Vector2(randf_range(-10, 10), -randf_range(50, 110)), -20.0, 0.4, _mage_col(i % 3 + 1))
				Fx.twinkle(get_parent(), global_position + Vector2(0, -2), _mage_col(1), 3.0, 0.16)
			if kind == "barb":
				# el bárbaro salta pateando el piso: más polvo, piedritas y un golpecito de cámara
				squash = Vector2(0.62, 1.45)
				Fx.dust(get_parent(), global_position, 4, 40.0, 4.0, 2.0)
				Fx.chunks(get_parent(), global_position, 2, [Pal.S, Pal.SS], 50.0, 40.0, global_position.y)
				Fx.shake(1.5, 0.08)
				Snd.play("pisoton", {"rate": 1.5, "vol": 0.35})
	elif buffer > 0.0 and not is_on_floor() and not double_jumped and not dashing:
		double_jumped = true
		velocity.y = -jump_v * DJ
		buffer = 0.0
		jump_cut = false
		if not melee():
			charge = -1.0
		squash = Vector2(0.75, 1.3)
		Snd.play("salto", {"rate": 1.35})
		if kind == "barb" and charge < 0.0:
			# el bárbaro da una vuelta carnero hacia adelante con el arma
			flip_t = FLIP_T
			Snd.play("tajo", {"rate": 0.8, "vol": 0.5})
		if kind == "mage":
			# el mago pisa un círculo mágico que aparece en el aire: se enciende, lo empuja y se deshace en brasas
			blink_t = BLINK_T
			twirl_t = TWIRL_T
			apex_fx = false
			squash = Vector2(0.65, 1.45)
			Snd.play("hechizo", {"rate": 1.5, "vol": 0.45})
			var c0 := global_position + Vector2(0, 2)
			Fx.ring(get_parent(), c0, _mage_col(1), 0.0, 13.0, 0.28, 0.3)
			Fx.ring(get_parent(), c0, _mage_col(0), 0.0, 8.0, 0.28, 0.24)
			Fx.ring(get_parent(), c0, _mage_col(2), -0.06, 17.0, 0.28, 0.3)
			for i in 8:
				var a2 := TAU * i / 8.0
				Fx.part(get_parent(), c0 + Vector2(cos(a2) * 11.0, sin(a2) * 3.0), Vector2(cos(a2) * 30.0, 40.0 + 20.0 * sin(a2)), -60.0, 0.4, _mage_col(i % 2 + 1))
			for i in 3:
				Fx.twinkle(get_parent(), c0 + Vector2(-10.0 + 10.0 * i, randf_range(-1, 1)), _mage_col(0), 3.0, 0.18 + 0.05 * i)
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
		var gmul := FALL_MUL if velocity.y > 0.0 else 1.0
		if kind == "mage" and not is_on_floor() and absf(velocity.y) < HANG and jump_held:
			gmul = 0.5  # arriba de todo queda un instante flotando con el abrigo abierto
		var vy0 := velocity.y
		velocity.y = minf(velocity.y + GRAV * gmul * dt, MAX_FALL)
		if kind == "mage" and not is_on_floor() and not apex_fx and velocity.y >= 0.0 and vy0 < 0.0:
			_apex_pop()

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
		apex_fx = false
		twirl_t = 0.0
		if not was_floor and fall_speed > 140.0:
			var k := minf(1.0, (fall_speed - 140.0) / 130.0)
			squash = Vector2(1.1 + 0.4 * k, 0.92 - 0.32 * k)
			Fx.dust(get_parent(), global_position, 2 + roundi(4 * k), 22.0 + 30.0 * k, 3.0, 1.4 + 1.0 * k)
			if k > 0.55:
				Fx.shock(get_parent(), global_position, Pal.S, 10.0 + 6.0 * k, 0.25)
				Fx.chunks(get_parent(), global_position, 2, [Pal.S, Pal.SS], 40.0, 30.0, global_position.y)
			Snd.play("aterrizar", {"vol": 0.5 + 0.5 * k})
			if kind == "mage":
				# cae liviano, frenado por la magia: un aro de su color y brasas que se levantan
				squash = Vector2(1.06 + 0.2 * k, 0.94 - 0.16 * k)
				Fx.ring(get_parent(), global_position + Vector2(0, -1), _mage_col(2), 0.0, 9.0 + 5.0 * k, 0.3, 0.25)
				for i in 3 + roundi(3 * k):
					Fx.part(get_parent(), global_position + Vector2(randf_range(-7, 7), -1), Vector2(randf_range(-25, 25), -randf_range(20, 55)), 40.0, 0.4, _mage_col(i % 3 + 1))
				if k > 0.3:
					# caída larga: aterriza agachado con una mano en el piso y el abrigo que cae después;
					# una onda de su color, líneas que se abren a los costados y un golpecito de cámara
					Fx.shock(get_parent(), global_position, _mage_col(1), 16.0 + 8.0 * k, 0.3)
					Fx.kick(Vector2(0, 1), 0.8 + 0.8 * k)
					Fx.shake(1.0 + k, 0.08)
					for sd in [-1.0, 1.0]:
						for i in 3:
							Fx.streak(get_parent(), global_position + Vector2(sd * 3.0, -1.0 - 2.0 * i), Vector2(sd * (150.0 - 30.0 * i), 0), 0.14, _mage_col(i % 2), 8.0)
					Fx.twinkle(get_parent(), gem_pos(), _mage_col(0), 3.0, 0.16)
			if kind == "barb":
				# cae pesado: siempre sacude, abre un aro de polvo y salta piedra
				squash = Vector2(1.3 + 0.3 * k, 0.75 - 0.2 * k)
				Fx.shake(1.5 + 2.0 * k, 0.1 + 0.08 * k)
				Fx.kick(Vector2(0, 1), 1.0 + 1.5 * k)
				Fx.shock(get_parent(), global_position, Pal.S, 12.0 + 6.0 * k, 0.25)
				Fx.chunks(get_parent(), global_position, 2 + roundi(2 * k), [Pal.S, Pal.SS], 50.0, 40.0, global_position.y)
				Snd.play("pisoton", {"rate": 1.25, "vol": 0.3 + 0.4 * k})
		elif not was_floor and fall_speed > 60.0:
			squash = Vector2(1.08, 0.93)
			Fx.dust(get_parent(), global_position, 2, 14.0, 3.0, 1.2)
		if not was_floor and fall_speed > 60.0:
			land_t = _anim_len("land", 0.0) * (0.5 if absf(velocity.x) > 10.0 else 1.0)
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
	block_t -= dt
	parry_inv -= dt
	fury_t -= dt
	land_t -= dt
	cast_t -= dt
	summon_t -= dt
	blink_t -= dt
	twirl_t -= dt
	swing_t += dt
	if drop_t > 0.0:
		drop_t -= dt
		if drop_t <= 0.0:
			set_collision_mask_value(2, true)
	if dash_t > 0.0:
		dash_t -= dt
		if dash_t <= 0.0: # frena seco al terminar
			velocity.x = signf(velocity.x) * minf(absf(velocity.x), speed)
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
	if melee():
		_attack_melee(dt)
		return
	if _tap("atacar") and dash_t <= 0.0:
		charge = 0.0
	if charge >= 0.0:
		if _down("atacar"):
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


# ---------------------------------------------------------------- caballero y bárbaro

## Escudo del caballero: mantener el especial lo levanta y gasta energía; recién levantado hace parry.
func _shield_step(dt: float, held: bool, pressed: bool) -> void:
	if shield and (not held or energy <= 0.0):
		shield = false
		if energy <= 0.0:  # se le cae el escudo: queda un rato sin energía
			energy_delay = 1.4
			Snd.play("metal", {"rate": 0.5, "vol": 0.7, "vary": false})
			Fx.burst(get_parent(), global_position + Vector2(face * 6, -10), 10, [Pal.C, Pal.B, Pal.W], 70.0, 20.0, 0.4, 200.0)
	elif not shield and held and pressed and dash_t <= 0.0:
		if energy < SH_MIN:
			no_energy()
		else:
			shield = true
			shield_t = 0.0
			energy -= SH_ON
			charge = -1.0
			Snd.play("escudo")
			squash = Vector2(0.85, 1.15)
			Fx.twinkle(get_parent(), global_position + Vector2(face * 7, -12), Pal.W, 4.0, 0.14)
	if shield:
		shield_t += dt
		energy = maxf(0.0, energy - SH_DRAIN * (0.5 if has_card("muralla") else 1.0) * dt)
		energy_delay = maxf(energy_delay, EN_DELAY)


## Furia del bárbaro: unos segundos de más daño; cuanto menos vida al activarla, más fuerte.
func _fury_step(dt: float, pressed: bool) -> void:
	if rage_t > 0.0:
		rage_t -= dt
		energy_delay = maxf(energy_delay, EN_DELAY)
		if rage_t <= 0.0:
			# se apaga: una bocanada de vapor y un aro que se cierra
			Snd.play("menu", {"rate": 0.6, "vol": 0.5, "vary": false})
			squash = Vector2(0.9, 1.1)
			Fx.dust(get_parent(), global_position + Vector2(0, -8), 6, 26.0, 16.0, 2.2, Pal.S)
			Fx.ring(get_parent(), global_position + Vector2(0, -10), Pal.S, 0.0, 14.0, 1.0, 0.25)
	if not pressed or rage_t > 0.0:
		return
	if energy < RAGE:
		no_energy()
		return
	energy -= RAGE
	energy_delay = EN_DELAY
	rage_mul = roundf((1.15 + 0.6 * (1.0 - float(hearts) / maxf(1.0, max_hearts))) * 100.0) / 100.0
	rage_t = RAGE_T * (2.0 if has_card("ira") else 1.0)
	var n := sprite.sprite_frames.get_frame_count("fury")
	fury_t = n / sprite.sprite_frames.get_animation_speed("fury") if n > 1 else 0.0
	charge = -1.0
	Snd.play("rugido", {"rate": 1.6, "vol": 0.9, "vary": false})
	Snd.play("escudo", {"rate": 0.6})
	Fx.popup(get_parent(), global_position + Vector2(0, -28), "FURIA X%.1f" % rage_mul, Pal.R, true)
	squash = Vector2(1.3, 0.8)
	Fx.shake(2.0, 0.15)
	Fx.burst(get_parent(), global_position + Vector2(0, -10), 14, [Pal.R, Pal.O, Pal.Y], 80.0, 40.0, 0.5, 120.0)
	Fx.ring(get_parent(), global_position + Vector2(0, -12), Pal.R, 0.0, 18.0, 1.0, 0.3)
	Fx.ring(get_parent(), global_position + Vector2(0, -12), Pal.O, -0.08, 24.0, 1.0, 0.3)
	Fx.shock(get_parent(), global_position, Pal.O, 18.0, 0.35)
	# el rugido: el juego se frena un instante, el piso tiembla y se rompe a sus pies, sube una columna de
	# brasas y sale una segunda onda más grande
	Fx.hitstop(0.08)
	Fx.impact(global_position + Vector2(0, -10), 0.1)
	Fx.shake(5.0, 0.3)
	Fx.kick(Vector2(0, 1), 2.0)
	Fx.ring(get_parent(), global_position + Vector2(0, -12), Pal.Y, -0.16, 34.0, 1.0, 0.35)
	Fx.shock(get_parent(), global_position, Pal.R, 32.0, 0.45)
	for i in 10:
		Fx.streak(get_parent(), global_position + Vector2(randf_range(-9, 9), -randf_range(0, 14)),
			Vector2(randf_range(-10, 10), -randf_range(120, 220)), 0.22 + 0.2 * randf(), [Pal.R, Pal.O, Pal.Y][i % 3], 9.0)
	if is_on_floor():
		Fx.chunks(get_parent(), global_position, 8, [Pal.S, Pal.SS, Pal.D], 80.0, 60.0, global_position.y)
		Fx.dust(get_parent(), global_position, 8, 44.0, 5.0, 2.4)


## Ataque cuerpo a cuerpo (chargeStep del original): apretar pega; mantener carga y al soltar
## con la carga llena sale el espadazo grande (caballero) o el giro del hacha (bárbaro).
func _attack_melee(dt: float) -> void:
	var can := not shield and dash_t <= 0.0 and fury_t <= 0.0 and cast_wind < 0.0 and summon_t <= 0.0
	var pressed := _tap("atacar")
	var held := _down("atacar")
	if pressed:
		atk_buf = 0.15
		if can:
			charge = 0.0
	atk_buf -= dt
	if atk_buf > 0.0 and shot_cool <= 0.0 and can:
		atk_buf = 0.0
		_swing()
	if charge >= 0.0 and not pressed:
		if not can:
			charge = -1.0
		elif not held:
			if charge >= chg_full():
				_big_swing()
			charge = -1.0
		else:
			var was := charge
			charge += dt
			# el caballero junta la carga en el mandoble levantado detrás de la cabeza; el bárbaro, en el hacha que lleva atrás, lista para girar
			var at := global_position + (Vector2(-face * 6, -23) if kind == "knight" else Vector2(-face * (13 if evo else 11), -9))
			if kind == "mage":
				at = gem_pos()
			if was < CHG_ON and charge >= CHG_ON:
				Snd.play("menu", {"rate": 0.75, "vol": 0.3, "vary": false})
			if was < chg_full() and charge >= chg_full():
				Snd.play("cargado", {"vary": false})
				Fx.twinkle(get_parent(), at, _mage_col(1) if kind == "mage" else Pal.Y, 6.0, 0.3)
				Fx.ring(get_parent(), at, _mage_col(1) if kind == "mage" else Pal.Y, 0.0, 9.0, 1.0, 0.22)
				if kind == "mage":
					# la gema se enciende: un segundo aro y el piso que se ilumina a sus pies
					Fx.ring(get_parent(), at, _mage_col(0), -0.05, 14.0, 1.0, 0.26)
					Snd.play("hechizo", {"rate": 1.2, "vol": 0.4})
					if is_on_floor():
						Fx.shock(get_parent(), global_position, _mage_col(2), 14.0, 0.3)
			# chispitas que se juntan en el arma levantada mientras carga
			if charge >= CHG_ON:
				chg_fx -= dt
				if chg_fx <= 0.0:
					var full := charge >= chg_full()
					chg_fx = 0.09 if full else 0.035
					var col := Pal.O if kind == "barb" else Pal.Y
					if kind == "mage":
						col = _mage_col(1 + randi() % 2)
						# la magia sube del piso hacia la gema: brasas que trepan alrededor del cuerpo
						if is_on_floor():
							Fx.part(get_parent(), global_position + Vector2(randf_range(-8, 8), -1), Vector2(randf_range(-4, 4), -randf_range(45, 80)), -30.0, 0.4, col)
					if full:
						Fx.part(get_parent(), at + Vector2(randf_range(-3, 3), randf_range(-3, 3)), Vector2(randf_range(-8, 8), -22), -30.0, 0.35, col)
					else:
						Fx.converge(get_parent(), at, 9.0 + randf() * 5.0, col if randf() < 0.6 else Pal.W, 0.18)
	if big and not big_fx and swing_t >= _big_hit_t():
		big_fx = true
		if kind == "mage":
			_slam_impact()
		else:
			_big_impact()
	if not chop_fx and not big and not spin:
		var chop_len := _anim_len("attack", 0.2) * haste()
		if not chop_arc and swing_t >= chop_len * CHOP_ARC:
			chop_arc = true
			var hand := global_position + Vector2(face * 3.0, -12.0)
			Fx.slash(get_parent(), hand, 16.0 if evo else 13.0, -115.0, 35.0, face, _barb_col(), 5.0, 0.12)
		if swing_t >= chop_len * CHOP_K:
			chop_fx = true
			_chop_impact()
	if _slash_active():
		_slash_hits()


## el espadazo llega al piso en la punta de la hoja: destello, chispas con la rampa del héroe (rojo el
## caballero, dorado el Paladín), cascotes que rebotan, polvo a los dos lados, un aro aplastado y temblor
func _big_impact() -> void:
	var ramp: Array = Pal.RAMP_Y if evo else Pal.RAMP_R
	var tip := global_position + Vector2(face * (21.0 if evo else 25.0), 0.0)
	Fx.hit(get_parent(), tip + Vector2(0, -3), Vector2(face * 0.4, -1.0), ramp[3], true)
	Fx.burst(get_parent(), tip + Vector2(0, -1), 12, [ramp[2], ramp[3], ramp[4]], 120.0, 50.0, 0.45, 260.0)
	Fx.shake(4.0, 0.15)
	Fx.kick(Vector2(0, 1), 1.5)
	if is_on_floor():
		Fx.chunks(get_parent(), tip, 7, [Pal.S, Pal.SS, Pal.D], 70.0, 40.0, global_position.y)
		Fx.dust(get_parent(), tip + Vector2(0, -1), 8, 30.0, 6.0, 2.4)
		Fx.shock(get_parent(), tip, ramp[3], 22.0, 0.3)
		Snd.play("aterrizar", {"rate": 0.7})


## el hachazo del bárbaro: la hoja pega adelante y abajo; chispas naranjas (rojas con furia), polvo,
## un par de cascotes, un aro chico y un temblor corto. Más liviano que el espadazo cargado
func _chop_impact() -> void:
	var ramp: Array = Pal.RAMP_R if evo or rage_t > 0.0 else Pal.RAMP_O
	var tip := global_position + Vector2(face * (12.0 if evo else 10.0), -2.0)
	Fx.hit(get_parent(), tip, Vector2(face, -0.6), ramp[3], false)
	Fx.burst(get_parent(), tip, 7, [ramp[2], ramp[3], ramp[4]], 90.0, 40.0, 0.3, 240.0)
	Fx.shake(2.0, 0.1)
	Fx.kick(Vector2(face * 0.6, 0.8), 1.0)
	if is_on_floor():
		Fx.chunks(get_parent(), tip + Vector2(0, 2), 3, [Pal.S, Pal.SS, Pal.D], 55.0, 30.0, global_position.y)
		Fx.dust(get_parent(), tip + Vector2(0, 1), 4, 22.0, 5.0, 1.8)
		Fx.shock(get_parent(), tip + Vector2(0, 2), ramp[3], 12.0, 0.2)
		Snd.play("aterrizar", {"rate": 0.9, "vol": 0.5})


## el color de las estelas del bárbaro, como las que traen dibujadas sus cuadros: naranja, rojo el Warlord
## y amarillo con la furia
func _barb_col() -> Color:
	if rage_t > 0.0:
		return Pal.Y
	return Pal.RAMP_R[3] if evo else Pal.RAMP_O[3]


func _anim_len(anim: String, fallback: float) -> float:
	var n := sprite.sprite_frames.get_frame_count(anim)
	return n / sprite.sprite_frames.get_animation_speed(anim) if n > 1 else fallback


## golpe normal: espadazo o hachazo hacia adelante
func _swing() -> void:
	shot_cool = cool * haste()
	swing_t = 0.0
	swing_id += 1
	big = false
	spin = false
	hit_keys.clear()
	velocity.x += face * 48.0
	squash = Vector2(1.2, 0.86)
	Snd.play("tajo", {"rate": 0.75 if kind == "barb" else (1.3 if kind == "mage" else 1.0)})
	Fx.kick(Vector2(face, 0), 0.5)
	if kind == "mage":
		# estocada con el bastón: la gema sale hacia adelante dejando una estela de su color, un destello en la
		# punta y chispas que se abren
		velocity.x -= face * 8.0
		var tip := global_position + Vector2(face * 15.0, -12.0)
		for i in 3:
			Fx.streak(get_parent(), global_position + Vector2(face * 4.0, -12.0 + (i - 1) * 2.0), Vector2(face * (190.0 - 30.0 * absi(i - 1)), 0), 0.1, _mage_col(0 if i == 1 else 1), 10.0)
		Fx.twinkle(get_parent(), tip, _mage_col(0), 3.5, 0.14)
		Fx.ring(get_parent(), tip, _mage_col(1), -0.03, 6.0, 1.0, 0.16)
		for i in 5:
			var a := deg_to_rad(-50.0 + 25.0 * i)
			Fx.part(get_parent(), tip, Vector2(face * cos(a), sin(a)) * randf_range(60, 120), 80.0, 0.28, _mage_col(i % 3))
		Snd.play("hechizo", {"rate": 2.0, "vol": 0.3})
		if is_on_floor():
			Fx.dust(get_parent(), global_position + Vector2(-face * 4.0, 0), 2, 26.0, 5.0, 1.4, Pal.S, -face)
	elif kind == "knight":
		# el tajo trae su media luna dibujada en los cuadros (roja, dorada el Paladín): acá van el polvo
		# que levanta el pie de atrás al pisar fuerte y las líneas de velocidad
		if is_on_floor():
			Fx.dust(get_parent(), global_position + Vector2(-face * 4.0, 0), 3, 34.0, 6.0, 1.6, Pal.S, -face)
		for i in 3:
			Fx.streak(get_parent(), global_position + Vector2(-face * (3.0 + 2.0 * i), -7.0 - 5.0 * i),
				Vector2(-face * 130.0, 0), 0.12, Pal.W, 6.0)
	else:
		# el hacha sube y baja en los cuadros: la media luna y el golpe contra el piso salen cuando baja
		# (ver _attack_melee); acá, el polvo del pie de atrás
		chop_fx = false
		chop_arc = false
		if is_on_floor():
			Fx.dust(get_parent(), global_position + Vector2(-face * 4.0, 0), 2, 28.0, 5.0, 1.6, Pal.S, -face)
	sprite.play("attack")
	sprite.frame = 0


## golpe cargado: el caballero baja la espada con todo; el bárbaro gira con el hacha
func _big_swing() -> void:
	shot_cool = cool * haste()
	swing_t = 0.0
	swing_id += 1
	hit_keys.clear()
	chop_fx = true
	chop_arc = true
	if kind == "barb":
		spin = true
		big = false
		spin_n = 3 if has_card("remolino") else 2
		Snd.play("poder", {"rate": 0.7})
		Snd.play("tajo", {"rate": 0.6})
		for i in range(1, spin_n):
			Snd.play("tajo", {"rate": 0.7 + 0.1 * (i - 1), "delay": SPIN_GAP * i})
		squash = Vector2(1.3, 0.8)
		Fx.shake(3.0, 0.2)
		Fx.burst(get_parent(), global_position + Vector2(0, -6), 12, [Pal.O, Pal.Y, Pal.W], 90.0, 20.0, 0.4, 160.0)
		# suelta la carga: un instante congelado, destello y el piso que salta alrededor
		Fx.hitstop(0.05)
		Fx.impact(global_position + Vector2(0, -9), 0.08)
		Fx.kick(Vector2(face, 0), 2.0)
		Fx.shock(get_parent(), global_position, _barb_col(), 30.0 if evo else 24.0, 0.3)
		if is_on_floor():
			Fx.chunks(get_parent(), global_position, 6, [Pal.S, Pal.SS, Pal.D], 90.0, 50.0, global_position.y)
			Fx.dust(get_parent(), global_position, 6, 50.0, 4.0, 2.2)
		sprite.play("spin")
		sprite.frame = 0
	elif kind == "mage":
		# bastonazo de fuego: baja el bastón con todo y la gema revienta contra el piso (ver _slam_impact)
		big = true
		big_fx = false
		spin = false
		Snd.play("poder", {"rate": 1.1})
		Snd.play("tajo", {"rate": 0.85})
		velocity.x += face * 60.0
		squash = Vector2(0.8, 1.3)
		Fx.kick(Vector2(face, 0), 1.2)
		Fx.slash(get_parent(), global_position + Vector2(face * 2.0, -12.0), 20.0 if evo else 17.0, -150.0, 60.0, face, _mage_col(1), 6.0, 0.16)
		Fx.slash(get_parent(), global_position + Vector2(face * 2.0, -12.0), 15.0 if evo else 13.0, -140.0, 50.0, face, _mage_col(0), 3.0, 0.13)
		sprite.play("big")
		sprite.frame = 0
	else:
		big = true
		big_fx = false  # el arco grande viene dibujado; el impacto contra el piso sale en _big_impact
		spin = false
		Snd.play("poder", {"rate": 0.8})
		Snd.play("tajo", {"rate": 0.7})
		velocity.x += face * 90.0
		squash = Vector2(1.35, 0.8)
		Fx.kick(Vector2(face, 0), 1.8)
		if is_on_floor():
			Fx.dust(get_parent(), global_position + Vector2(-face * 4.0, 0), 3, 30.0, 4.0, 1.6, Pal.S, -face)
		sprite.play("big")
		sprite.frame = 0


func _spin_idx() -> int:
	return int(swing_t / SPIN_GAP)


## cuándo pega cada golpe (slashActive del original)
func _slash_active() -> bool:
	if spin:
		var k := _spin_idx()
		return k < spin_n and swing_t - k * SPIN_GAP < SPIN_HIT
	if big and kind == "mage":  # pega cuando el bastón llega abajo
		return swing_t >= _big_hit_t() - 0.04 and swing_t < _big_hit_t() + 0.1
	return swing_t < (0.16 if big else 0.1)


func _swing_key() -> int:
	return swing_id * 4 + (_spin_idx() if spin else 0)


## la zona del golpe (slashBoxOf y slashBoxEvo del original, con el héroe HD de 18 de alto)
func slash_box() -> Rect2:
	var gx := global_position.x
	var gy := global_position.y
	if spin:
		return Rect2(gx - 34, gy - 22, 68, 24) if evo else Rect2(gx - 26, gy - 20, 52, 22)
	var near := 2.0
	var w := 18.0
	var top := 24.0
	var h := 26.0
	var knight := kind == "knight"  # el mandoble del caballero llega más lejos que el hacha
	if big:
		near = -2.0 if kind != "mage" else -6.0  # la explosión del bastonazo también agarra a los que tiene encima
		w = (52.0 if evo else 44.0) if knight else (46.0 if evo else 36.0)
		top = 36.0 if knight else (34.0 if evo else 32.0)
		h = top + 4.0
	elif knight:
		w = 28.0 if evo else 24.0
		top = 27.0
		h = 29.0
	elif evo:
		w = 28.0
		top = 26.0
		h = 28.0
	var x := gx + near if face > 0 else gx - near - w
	return Rect2(x, gy - top, w, h)


## base del daño: hachazo 3, espadazo 2, cargado 4, cada vuelta del giro 2
func _slash_base() -> int:
	if spin:
		return 2
	if big:
		return 3 if kind == "mage" else 4
	if kind == "mage":
		return 1
	return 3 if kind == "barb" else 2


## Lo que toca el golpe mientras está activo: bichos, el jefe, lo que cae, monedas y (el cargado) proyectiles.
func _slash_hits() -> void:
	var hb := slash_box()
	var key := _swing_key()
	var war := evo and kind == "barb" and spin and rage_t > 0.0  # el Warlord en furia aturde con el giro
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.dead or e.spawn > 0.0 or not e.has_method("hit_rect") or not e.hit_rect().intersects(hb):
			continue
		var id := e.get_instance_id()
		if hit_keys.get(id, -1) == key:
			continue
		hit_keys[id] = key
		var d := face
		if spin:
			d = 1 if e.global_position.x >= global_position.x else -1
		# el caballero que le pega a uno aturdido por su parry: crítico seguro
		var how := "riposte" if kind == "knight" and e.get("parry_t") != null and e.parry_t > 0.0 else "sword"
		e.take_hit(dmg(_slash_base()), d, "fire" if big and kind == "mage" else how)
		if big and kind == "mage" and not e.dead and e.has_method("apply_burn"):
			e.apply_burn(has_card("brasas"), evo)
		if war and not e.dead and e.has_method("parried"):
			e.parried(d, 1.6)
	var b = game.boss if game != null else null
	if b != null and is_instance_valid(b) and b.active() and b.body().intersects(hb):
		var bid: int = b.get_instance_id()
		if war and hit_keys.get(-bid, -1) != swing_id:
			hit_keys[-bid] = swing_id
			b.war_stun()
		if hit_keys.get(bid, -1) != key:
			hit_keys[bid] = key
			var bb: Rect2 = b.body()
			var hx := maxf(hb.position.x, bb.position.x + 3.0) + 2.0 if face > 0 else minf(hb.end.x, bb.end.x - 3.0) - 2.0
			var riposte: bool = kind == "knight" and b.state == "stun" and b.parry_stun
			b.damage(dmg(_slash_base()), hx, global_position.y - 10.0, riposte)
			if big and kind == "mage":
				b.apply_burn(has_card("brasas"), evo)
	for h in get_tree().get_nodes_in_group("peligros"):
		if h.phase == "fall" and h.box().intersects(hb):
			h.smash()
	for c in get_tree().get_nodes_in_group("monedas"):
		if c.can_take() and hb.has_point(c.global_position):
			c.take()
	if big:
		_slash_clear(hb)


## el espadazo cargado rompe flechas y ondas
func _slash_clear(hb: Rect2) -> void:
	var n := 0
	for a in get_tree().get_nodes_in_group("flechas_malas"):
		if not a.stuck and hb.has_point(a.global_position):
			Fx.burst(get_parent(), a.global_position, 6, [Pal.Y, Pal.W, Pal.O], 70.0, 30.0, 0.3, 220.0)
			a.queue_free()
			n += 1
	for sp in get_tree().get_nodes_in_group("babas"):
		if hb.grow(2.0).has_point(sp.global_position):
			sp.splat()
			n += 1
	for w in get_tree().get_nodes_in_group("ondas"):
		if hb.intersects(Rect2(w.position.x - 4, w.GROUND - 7, 8, 7)):
			Fx.burst(get_parent(), Vector2(w.position.x, w.GROUND - 4), 6, [Pal.Y, Pal.W, Pal.O], 70.0, 30.0, 0.3, 220.0)
			w.queue_free()
			n += 1
	if n > 0:
		Snd.play("clavar", {"rate": 1.9, "vary": false})
		if game != null:
			game.add_score(5 * n)


## El escudo frena el golpe: un empujoncito, chispas y un poco de energía.
func _block(dir: float, src: Object) -> void:
	if src != null and src.has_method("blocked"):
		src.blocked(dir)
	if block_t > 0.0:
		return
	block_t = 0.25
	energy = maxf(0.0, energy - SH_BLOCK * (0.5 if has_card("muralla") else 1.0))
	energy_delay = maxf(energy_delay, EN_DELAY)
	velocity.x = dir * 120.0
	velocity.y = minf(velocity.y, -60.0)
	squash = Vector2(1.2, 0.85)
	Snd.play("metal", {"rate": 1.3, "vol": 0.8})
	Fx.kick(Vector2(dir, 0), 1.2)
	var at := global_position + Vector2(face * 10.0, -12.0)
	Fx.hit(get_parent(), at, Vector2(-dir, 0), Pal.C)
	Fx.burst(get_parent(), at, 8, [Pal.C, Pal.W, Pal.Y], 80.0, 20.0, 0.3, 200.0)


## Parry: levantar el escudo justo antes del golpe. No gasta (devuelve un poco), aturde al que pegó,
## devuelve flechas y espadas, empuja a los que estén cerca y deja al caballero inmune un ratito.
func _parry(dir: float, src: Object) -> void:
	if block_t > 0.0:
		return
	block_t = 0.3
	energy = minf(EN_MAX, energy + 12.0)
	if src != null and src.has_method("parried"):
		src.parried(-dir, 2.0)
	var at := global_position + Vector2(face * 10.0, -12.0)
	Snd.play("metal", {"rate": 1.9, "vol": 1.0, "vary": false})
	Snd.play("critico", {"rate": 1.35, "vol": 0.55, "vary": false})
	Snd.play("moneda", {"rate": 2.2, "vol": 0.5, "delay": 0.06, "vary": false})
	Snd.play("dash", {"rate": 0.55, "vol": 0.8})
	squash = Vector2(0.75, 1.25)
	Fx.popup(get_parent(), global_position + Vector2(0, -28), "¡PARRY!", Pal.Y, true)
	Fx.hitstop(0.13)
	Fx.slowmo = maxf(Fx.slowmo, 0.25)
	Fx.zoom_t = 0.3
	Fx.zoom_at = at
	Fx.shake(2.2, 0.16)
	Fx.hit(get_parent(), at, Vector2(-dir, 0), Pal.Y, true)
	Fx.burst(get_parent(), at, 14, [Pal.W, Pal.Y, Pal.C], 120.0, 20.0, 0.3, 0.0)
	for i in 3:
		Fx.ring(get_parent(), global_position + Vector2(0, -9), [Pal.W, Pal.Y, Pal.C][i], -0.06 * i, 30.0, 1.0, 0.35)
	for i in 16:
		var a := i / 16.0 * TAU
		Fx.part(get_parent(), global_position + Vector2(cos(a) * 6, -9 + sin(a) * 4), Vector2(cos(a) * 170, sin(a) * 90), 0.0, 0.28, Pal.Y if i % 2 == 1 else Pal.W)
	Fx.dust(get_parent(), global_position, 6, 60.0, 6.0, 1.8)
	# empuja a todos los bichos cerca
	var c := global_position + Vector2(0, -9)
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e == src or e.dead or e.spawn > 0.0 or not e.has_method("parried"):
			continue
		var d: Vector2 = e.global_position + Vector2(0, -4) - c
		if d.length() < PARRY_R:
			e.parried(signf(d.x) if d.x != 0.0 else -dir, 0.7)
	parry_inv = PARRY_INV
	if evo:
		heal_wave()


## Paladín: el parry manda una onda que cura un corazón.
func heal_wave() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - heal_at < 0.8:
		return
	heal_at = now
	var at := global_position + Vector2(0, -9)
	Snd.play("oleada", {"rate": 1.5, "vol": 0.7, "vary": false})
	Snd.play("moneda", {"rate": 0.9, "vol": 0.5, "vary": false})
	for i in 3:
		Fx.ring(get_parent(), at, Pal.L if i == 1 else Pal.Y, -0.07 * i, 34.0, 1.0, 0.45)
	Fx.burst(get_parent(), at, 16, [Pal.Y, Pal.L, Pal.W], 90.0, 20.0, 0.6, -20.0)
	if hearts < max_hearts:
		hearts += 1
		hearts_changed.emit()
		Fx.popup(get_parent(), global_position + Vector2(0, -36), "+1 VIDA", Pal.L)


# ---------------------------------------------------------------- mago

## los tonos de la magia del mago, del más claro al más oscuro: carmesí como su gema; verde de almas el Nigromante
func _mage_col(i: int) -> Color:
	var c: Array = [Pal.RAMP_L[4], Pal.L, Pal.G, Pal.RAMP_G[1]] if evo else [Pal.RAMP_R[4], Pal.RAMP_R[3], Pal.R, Pal.RAMP_R[1]]
	return c[clampi(i, 0, 3)]


## los tonos del fuego del mago: amarillo, naranja y rojo; verde el del Nigromante
func _fire_cols() -> Array:
	return [Pal.RAMP_L[4], Pal.L, Pal.G, Pal.RAMP_G[1]] if evo else [Pal.RAMP_Y[4], Pal.Y, Pal.O, Pal.R]


## dónde está la gema del bastón según la pose (para que las chispas salgan de ahí)
func gem_pos() -> Vector2:
	var a := String(sprite.animation)
	if a in ["charge", "charge_hold", "charge_walk"]:  # el bastón cruzado detrás de la cabeza
		return global_position + Vector2(-face * 7.0, -21.0)
	if a == "cast":
		return global_position + Vector2(face * 14.0, -7.0)
	if a == "run":
		return global_position + Vector2(face * 6.0, -24.0)
	return global_position + Vector2(face * 7.0, -23.0)


func _big_hit_t() -> float:
	return _anim_len("big", 0.3) * SLAM_K if kind == "mage" else BIG_HIT


## arriba de todo del salto: el abrigo se abre de golpe; un destello en la gema, un aro y un soplo de brasas
func _apex_pop() -> void:
	apex_fx = true
	squash = Vector2(1.14, 0.9)
	Snd.play("hechizo", {"rate": 2.2, "vol": 0.18})
	Fx.twinkle(get_parent(), gem_pos(), _mage_col(0), 3.5, 0.18)
	Fx.ring(get_parent(), global_position + Vector2(0, -10), _mage_col(2), 0.0, 13.0, 0.5, 0.24)
	for i in 6:
		var a := PI + PI * i / 5.0  # hacia arriba, en abanico
		Fx.part(get_parent(), global_position + Vector2(cos(a) * 8.0, -10.0), Vector2(cos(a) * 45.0, sin(a) * 30.0), 70.0, 0.35, _mage_col(1 + i % 2))


## Bola de fuego: el especial del mago. Estira el bastón (un instante de aviso con chispas que se juntan
## en la gema) y sale la bola con retroceso.
func _cast_step(dt: float, pressed: bool) -> void:
	if cast_wind >= 0.0:
		cast_wind -= dt
		if cast_wind < 0.0:
			_fire()
	if not pressed or cast_wind >= 0.0 or summon_t > 0.0 or hurt_t > 0.0:
		return
	if energy < FIRE_COST:
		no_energy()
		return
	energy -= FIRE_COST
	energy_delay = EN_DELAY
	charge = -1.0
	cast_t = _anim_len("cast", 0.26)
	cast_wind = FIRE_WIND
	sprite.play("cast")
	sprite.frame = 0
	squash = Vector2(1.15, 0.88)  # se encoge un instante antes de estirarse
	var at := global_position + Vector2(face * 6.0, -13.0)
	for i in 6:
		Fx.converge(get_parent(), at, 8.0 + randf() * 6.0, _mage_col(i % 3), 0.07)
	Snd.play("hechizo", {"rate": 1.7, "vol": 0.5})


func _fire() -> void:
	var f := FireballScript.new()
	f.face = face
	f.evo = evo
	f.big = has_card("inferno")
	f.long_burn = has_card("brasas")
	f.dmg = dmg(2)
	f.game = game
	var at := global_position + Vector2(face * 12.0, -13.0)
	f.global_position = at
	get_parent().add_child(f)
	velocity.x -= face * 46.0
	squash = Vector2(0.78, 1.2)
	Snd.play("fuego")
	Snd.play("poder", {"rate": 1.3, "vol": 0.6})
	Fx.shake(1.5, 0.1)
	Fx.kick(Vector2(-face, 0), 1.6)
	# fogonazo en la gema: estrella, aro, chispas hacia adelante y el aire que empuja hacia atrás
	var c := _fire_cols()
	Fx.hit(get_parent(), at, Vector2(face, 0), c[1], true)
	Fx.ring(get_parent(), at, c[2], 0.0, 10.0, 1.0, 0.22)
	Fx.burst(get_parent(), at, 9, [c[0], c[1], c[2]], 80.0, 10.0, 0.25, 0.0)
	for i in 4:
		Fx.streak(get_parent(), global_position + Vector2(-face * randf_range(0, 6), -randf_range(4, 18)), Vector2(-face * randf_range(120, 190), randf_range(-10, 10)), 0.12, _mage_col(i % 2), 7.0)
	if is_on_floor():
		Fx.dust(get_parent(), global_position + Vector2(-face * 3.0, 0), 3, 30.0, 4.0, 1.6, Pal.S, -face)


## el bastonazo cargado: la gema revienta contra el piso. Fogonazo, una columna de llamas, lenguas de fuego
## que corren por el piso para los dos lados, cascotes, humo y temblor
func _slam_impact() -> void:
	var tip := global_position + Vector2(face * (22.0 if evo else 19.0), -1.0)
	var c := _fire_cols()
	FireballScript.blast(get_parent(), tip + Vector2(0, -5), 15.0 if evo else 13.0, c)
	Fx.hit(get_parent(), tip + Vector2(0, -3), Vector2(face * 0.3, -1.0), c[1], true)
	Fx.burst(get_parent(), tip + Vector2(0, -2), 16, c, 130.0, 60.0, 0.5, 240.0)
	Fx.ring(get_parent(), tip + Vector2(0, -4), c[1], 0.0, 18.0, 1.0, 0.28)
	Fx.hitstop(0.05)
	Fx.shake(4.0, 0.16)
	Fx.kick(Vector2(0, 1), 1.6)
	Snd.play("explotar", {"rate": 1.0, "vol": 0.8})
	Snd.play("fuego", {"rate": 0.7, "vol": 0.7})
	Snd.boom(0.45)
	for i in 8:  # la columna
		Fx.streak(get_parent(), tip + Vector2(randf_range(-5, 5), -randf_range(0, 8)), Vector2(randf_range(-12, 12), -randf_range(130, 240)), 0.18 + 0.14 * randf(), c[1 + i % 3], 9.0)
	for i in 5:  # lenguas que corren por el piso
		for sd in [-1.0, 1.0]:
			Fx.part(get_parent(), tip + Vector2(sd * (3.0 + 4.0 * i), -1), Vector2(sd * (40.0 + 14.0 * i), -randf_range(30, 70)), 120.0, 0.3 + 0.05 * i, c[1 + i % 3], 2 if i < 2 else 1)
	if is_on_floor():
		Fx.chunks(get_parent(), tip, 6, [Pal.S, Pal.SS, Pal.D], 75.0, 50.0, global_position.y)
		Fx.dust(get_parent(), tip, 6, 34.0, 8.0, 2.4, Pal.SS)
		Fx.shock(get_parent(), tip, c[2], 24.0, 0.32)


## Nigromante: el botón de poder (media barra de energía) levanta dos esqueletos aliados al azar, de hacha
## o de arco. Si ya tenía, los viejos se deshacen.
func _necro_step(pressed: bool) -> void:
	if not pressed or summon_t > 0.0 or cast_wind >= 0.0:
		return
	if energy < SUMMON_COST:
		no_energy()
		return
	energy -= SUMMON_COST
	energy_delay = EN_DELAY
	charge = -1.0
	summon_t = maxf(0.4, _anim_len("summon", 0.0))
	for a in get_tree().get_nodes_in_group("aliados"):
		a.crumble()
	var ground := is_on_floor()
	for i in 2:
		var a := AllyScript.new()
		a.kind = "skaxe" if randf() < 0.5 else "skarch"
		a.owner_hero = self
		a.game = game
		a.face = float(face)
		a.cool = 0.5 + i * 0.35
		a.global_position = global_position + Vector2(16.0 if i == 1 else -16.0, 0.0 if ground else -2.0)
		get_parent().add_child(a)
	Fx.popup(get_parent(), global_position + Vector2(0, -30), "¡ALZAOS!", Pal.L, true)
	Snd.play("posesion", {"rate": 1.4, "vol": 0.8, "vary": false})
	Snd.play("huesos", {"rate": 0.7})
	Snd.play("huesos", {"rate": 0.9, "delay": 0.18})
	squash = Vector2(0.75, 1.3)
	Fx.hitstop(0.05)
	Fx.shake(2.5, 0.2)
	# el círculo de invocación: un aro de almas que se cierra hacia él, tierra que salta y almas que suben
	var at := global_position
	Fx.shock(get_parent(), at, Pal.L, 30.0, 0.45)
	Fx.shock(get_parent(), at, Pal.G, 22.0, 0.35)
	for i in 22:
		var ang := TAU * i / 22.0
		Fx.part(get_parent(), at + Vector2(cos(ang) * 22.0, -1.0 + sin(ang) * 3.0), Vector2(-cos(ang) * 30.0, -randf_range(20, 50)), -15.0, 0.6, Pal.W if i % 3 == 0 else Pal.L)
	Fx.chunks(get_parent(), at, 8, [Pal.W, Pal.S, Pal.SS], 60.0, 90.0, at.y)
	for i in 6:
		Fx.streak(get_parent(), at + Vector2(randf_range(-14, 14), -randf_range(0, 6)), Vector2(0, -randf_range(90, 170)), 0.25 + 0.15 * randf(), Pal.L if i % 2 == 0 else Pal.G, 9.0)
	for i in 3:
		Fx.twinkle(get_parent(), gem_pos() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), Pal.L, 4.0, 0.2 + 0.06 * i)


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
	shot_cool = cool * (1.5 if evo and not power else 1.0)
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


## Lo llaman los enemigos (src: quién pega, para el parry). Devuelve true si el golpe entró.
func hurt(from_x: float, amount: int = 1, src: Object = null) -> bool:
	if dead or invuln > 0.0 or ghost_t > 0.0 or stomp_inv > 0.0 or parry_inv > 0.0:
		return false
	if game != null and game.state != "play":
		return false
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = -face
	if shield:
		# se da vuelta hacia el golpe: el escudo siempre queda entre él y lo que le pega
		face = -int(dir)
		sprite.flip_h = face < 0
		if shield_t < PARRY:
			_parry(dir, src)
		else:
			_block(dir, src)
		return false
	hearts = maxi(0, hearts - amount)
	invuln = 1.4
	hurt_t = 0.3
	charge = -1.0
	dash_t = 0.0
	cast_wind = -1.0
	cast_t = 0.0
	summon_t = 0.0
	flash_t = 0.09
	velocity = Vector2(dir * 140.0, -170.0)
	squash = Vector2(1.3, 0.75)
	Snd.play("dano")
	Fx.hitstop(0.09 if not bot else 0.05)
	Fx.shake(5.0 if not bot else 2.5, 0.28 if not bot else 0.16)
	if not bot:
		Fx.flash_red = 0.18
	Fx.kick(Vector2(dir, 0), 2.5 if not bot else 1.2)
	hurt_by.emit(src)
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


## ¡Evolución! Vida llena y otro diseño. Cazador: dos flechas por disparo y veneno con el botón de poder;
## Paladín: espada más larga y el parry cura; Warlord: martillo más ancho y la furia acelera y aturde.
func evolve() -> void:
	evo = true
	# cambia de ropa en el destello: mismo cuadro de la misma animación, con el diseño nuevo
	if evo_frames != null:
		var anim := sprite.animation
		var fr := sprite.frame
		var prog := sprite.frame_progress
		sprite.sprite_frames = evo_frames
		sprite.play(anim)
		sprite.set_frame_and_progress(fr, prog)
		var edir: String = SPR + HEROES[kind].evo_dir + "/"
		if ResourceLoader.exists(edir + "aim_bow.png"):
			bow.texture = load(edir + "aim_bow.png")
	hearts = max_hearts
	hearts_changed.emit()
	invuln = maxf(invuln, 1.0)
	charge = -1.0
	flash_t = 0.2
	squash = Vector2(0.6, 1.5)
	Fx.popup(get_parent(), global_position + Vector2(0, -26), HEROES[kind].evo, Pal.Y, true)
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


## Qué animación va para el caballero y el bárbaro.
func _pick_melee(anim: String, has: Callable, dt: float) -> void:
	var want := anim
	if dead:
		want = "death"
	elif hurt_t > 0.0 and has.call("hurt"):
		want = "hurt"
	elif fury_t > 0.0 and has.call("fury"):
		want = "fury"
	elif shield and has.call("shield"):
		want = "shield"
	elif spin and swing_t < spin_n * SPIN_GAP:
		want = "spin"
	elif big and swing_t < _anim_len("big", 0.3):
		want = "big"
	elif not big and not spin and swing_t < _anim_len("attack", 0.2):
		want = "attack"
	elif summon_t > 0.0 and (has.call("summon") or has.call("cast")):
		want = "summon" if has.call("summon") else "cast"
	elif cast_t > 0.0 and has.call("cast"):
		want = "cast"
	elif charge >= 0.08 and has.call("charge"):
		# levanta el arma una vez y después la sostiene en alto: quieto respira y tiembla, caminando avanza con ella
		want = "charge"
		var raised: bool = String(sprite.animation) in ["charge_hold", "charge_walk"] or (sprite.animation == "charge" and not sprite.is_playing())
		if raised:
			if is_on_floor() and absf(velocity.x) > 10.0 and has.call("charge_walk"):
				want = "charge_walk"
			elif has.call("charge_hold"):
				want = "charge_hold"
			elif sprite.animation != "charge":
				want = sprite.animation
	# recién aterrizado: se agacha un instante (con armadura pesa) antes de quedarse quieto o seguir corriendo
	if land_t > 0.0 and want in ["idle", "run"] and is_on_floor() and has.call("land"):
		want = "land"
	# el mago: en el doble salto gira envuelto en el abrigo y arriba de todo del salto lo abre como alas
	if want in ["jump", "fall"] and twirl_t > 0.0 and has.call("twirl"):  # doble salto: gira envuelto en el abrigo
		if sprite.animation != "twirl":
			sprite.play("twirl")
		sprite.pause()
		var tn := sprite.sprite_frames.get_frame_count("twirl")
		sprite.frame = clampi(int((1.0 - twirl_t / TWIRL_T) * tn), 0, tn - 1)
		idle_t = 0.0
		flourish_t = 0.0
		return
	if want in ["jump", "fall"] and absf(velocity.y) < 75.0 and has.call("apex"):
		if sprite.animation != "apex":
			sprite.play("apex")
		sprite.pause()
		var an := sprite.sprite_frames.get_frame_count("apex")
		sprite.frame = clampi(int((velocity.y + 75.0) / 150.0 * an), 0, an - 1)
		idle_t = 0.0
		flourish_t = 0.0
		return
	# en el aire el cuadro sale de la velocidad y no del reloj
	if want in ["jump", "fall"] and has.call(want):
		if sprite.animation != want:
			sprite.play(want)
		sprite.pause()
		sprite.frame = _air_frame(want)
		idle_t = 0.0
		flourish_t = 0.0
		return
	# quieto un rato: floreo con la espada (una vez y vuelve a esperar)
	if want == "idle" and has.call("flourish"):
		idle_t += dt
		if flourish_t <= 0.0 and idle_t > 5.0:
			flourish_t = _anim_len("flourish", 0.0)
			idle_t = -5.0
			Snd.play("tajo", {"rate": 1.35, "vol": 0.35})
			if kind == "mage":
				Snd.play("hechizo", {"rate": 1.4, "vol": 0.3, "delay": flourish_t * 0.4})
			else:
				Snd.play("metal", {"rate": 2.0, "vol": 0.25, "delay": flourish_t * 0.55, "vary": false})
		if flourish_t > 0.0:
			flourish_t -= dt
			want = "flourish"
	else:
		idle_t = 0.0
		flourish_t = 0.0
	if sprite.animation != want:
		sprite.play(want)
	elif not sprite.is_playing() and want in ["idle", "run", "fall", "charge_hold", "charge_walk"]:
		sprite.play(want)


## En el aire: despega estirado, encoge las piernas mientras sube, arriba de todo la capa empieza a volar
## y cae con las piernas estiradas. Subiendo va según lo que le queda de impulso; cayendo, según lo rápido que cae.
func _air_frame(anim: String) -> int:
	var n := sprite.sprite_frames.get_frame_count(anim)
	var k: float = 1.0 - clampf(-velocity.y / jump_v, 0.0, 1.0) if anim == "jump" else clampf(velocity.y / 160.0, 0.0, 1.0)
	return mini(n - 1, int(k * n))


## Rebote al pisarle el yelmo al jefe.
func boss_bounce() -> void:
	var held := _down("saltar")
	velocity.y = -jump_v * 1.1 if held else -260.0
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
	var held := _down("saltar")
	velocity.y = -jump_v * 1.05 if held else -210.0
	jump_cut = not held
	stomp_inv = 0.22
	recent_bottoms.clear()
	double_jumped = false
	air_dash = false
	squash = Vector2(0.8, 1.25)
	if kind == "mage":  # rebota en el bicho con un giro
		twirl_t = TWIRL_T
		apex_fx = false
		Fx.ring(get_parent(), global_position, _mage_col(1), 0.0, 9.0, 0.35, 0.2)


func _animate(dt: float) -> void:
	sprite.flip_h = face < 0
	var anim := "idle"
	if not is_on_floor():
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 10.0:
		anim = "run"
	var has := func(a: String) -> bool: return sprite.sprite_frames.get_frame_count(a) > 1
	if melee():
		_pick_melee(anim, has, dt)
	elif dead and has.call("death"):
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
	# el ciclo de correr va con la velocidad (sin patinar al arrancar o frenar); el giro da un barrido por golpe
	var ss := 1.0
	match sprite.animation:
		"run":
			ss = clampf(absf(velocity.x) / speed, 0.55, 1.3)
		"charge_walk":
			ss = clampf(absf(velocity.x) / (speed * 0.6), 0.5, 1.2)
		"spin":
			ss = sprite.sprite_frames.get_frame_count("spin") / (SPIN_GAP * SPIN_HITS * sprite.sprite_frames.get_animation_speed("spin"))
		"attack", "big":
			ss = 1.0 / haste()
	sprite.speed_scale = ss
	# pisadas con armadura: suenan y levantan polvo cuando el pie toca el piso (dos por vuelta del ciclo)
	if melee() and String(sprite.animation) in ["run", "charge_walk"] and is_on_floor() and not dead:
		var cur := sprite.frame
		var half := int(sprite.sprite_frames.get_frame_count(sprite.animation) / 2.0)
		if cur != step_fr and half >= 2 and cur % half == int(half / 2.0):  # el cuadro con las piernas más abiertas
			Snd.play("paso", {"rate": 1.9 if kind == "knight" else (2.4 if kind == "mage" else 1.5), "vol": 0.1 if kind == "mage" else 0.22})
			Fx.dust(get_parent(), global_position + Vector2(-face * 2, 0), 1, 16.0, 6.0, 1.3, Pal.S, -face)
		step_fr = cur
	else:
		step_fr = -1
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 12.0))
	# respiración al apuntar: el cuerpo sube y baja y se ensancha apenas, además de la capa del loop
	var breath := Vector2.ONE
	sprite.offset.y = base_oy
	if sprite.animation == "aim":
		var b := sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.9)
		breath = Vector2(1.0 + 0.015 * b, 1.0 - 0.025 * b)
		sprite.offset.y = base_oy + roundf(b)
	# en el aire se estira un poco con la velocidad (subiendo y cayendo) y arriba de todo vuelve a su forma;
	# cayendo rápido le pasa el viento por al lado
	var air := Vector2.ONE
	if not is_on_floor() and not dead and dash_t <= 0.0:
		var v := clampf((absf(velocity.y) - 60.0) / (MAX_FALL - 60.0), 0.0, 1.0)
		air = Vector2(1.0 - 0.05 * v, 1.0 + 0.08 * v)
		if velocity.y > 170.0 and Engine.get_physics_frames() % 4 == 0:
			Fx.streak(get_parent(), global_position + Vector2(randf_range(-7, 7), -randf_range(2, 18)),
				Vector2(0, -110.0), 0.1, Pal.W if randf() < 0.5 else Pal.S, 6.0)
	sprite.scale = squash * breath * air * 0.5
	if kind == "mage" and not dead:
		if twirl_t > 0.0 and not is_on_floor() and Engine.get_physics_frames() % 2 == 0:
			# el giro del doble salto: brasas que salen en espiral alrededor del abrigo
			var ang := (1.0 - twirl_t / TWIRL_T) * TAU * 2.0
			Fx.part(get_parent(), global_position + Vector2(cos(ang) * 9.0, -10.0 + sin(ang) * 3.0), Vector2(cos(ang) * 40.0, -20.0), 40.0, 0.3, _mage_col(randi() % 3))
	# vuelta carnero del bárbaro: gira alrededor del centro del cuerpo, con fantasmas atrás
	sprite.position = Vector2.ZERO
	if flip_t > 0.0:
		flip_t -= dt
		if is_on_floor() or dead or String(sprite.animation) not in ["jump", "fall"]:
			flip_t = 0.0
		if flip_t > 0.0:
			var k := 1.0 - flip_t / FLIP_T
			k = 1.0 - pow(1.0 - k, 2.0)  # arranca rápido y frena al final
			sprite.position = Vector2(0, -FLIP_C)
			sprite.offset.y = base_oy + FLIP_C * 2.0
			sprite.rotation = face * TAU * k
			if Engine.get_physics_frames() % 2 == 0:
				Fx.afterimage(get_parent(), sprite, Pal.RAMP_O[2] if not evo else Pal.RAMP_R[2])
		else:
			sprite.rotation = 0.0
	# el arco y la flecha no respiran: quedan clavados para dar tensión
	bow.visible = sprite.animation == "aim"
	bow.flip_h = sprite.flip_h
	# parpadeo de invulnerable, fantasma del dash y brillo de carga
	var m := Color.WHITE
	if kind == "mage" and evo:
		m = Color(1.3, 1.3, 1.38)  # el Nigromante es muy oscuro: un poco más claro para que se lea de noche y en el castillo
	if ghost_t > 0.0:
		m = Color(0.7, 0.9, 1.0, 0.55)
	elif invuln > 0.0 and int(invuln * 20.0) % 2 == 0:
		m.a = 0.3
	elif charge >= chg_full() and int(charge * 16.0) % 2 == 0:
		m = Color(1.6, 1.6, 1.8)
	elif rage_t > 0.0:
		# furia: late en rojo, más rápido cuando se está por terminar
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * (18.0 if rage_t < 1.0 else 9.0))
		m = Color(1.0 + 0.45 * beat, 1.0 - 0.25 * beat, 1.0 - 0.3 * beat)
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
	# furia: brasas que suben y, del Warlord, el aura que acelera
	if rage_t > 0.0 and not dead:
		if randf() < 0.45:
			Fx.part(get_parent(), global_position + Vector2(randf_range(-6, 6), -randf_range(2, 20)), Vector2(randf_range(-6, 6), -30), -20.0, 0.4, Pal.R if randf() < 0.5 else (Pal.O if randf() < 0.7 else Pal.Y))
		if (absf(velocity.x) > 40.0 or not is_on_floor()) and Engine.get_physics_frames() % 5 == 0:
			Fx.afterimage(get_parent(), sprite, Pal.R)  # con la furia deja una estela roja al correr y saltar
		if is_on_floor() and absf(velocity.x) > 40.0 and Engine.get_physics_frames() % 6 == 0:
			Fx.part(get_parent(), global_position + Vector2(-signf(velocity.x) * 3.0, -1), Vector2(-signf(velocity.x) * 20.0, -30), 60.0, 0.35, Pal.O if randf() < 0.6 else Pal.Y)
		if evo and Engine.get_physics_frames() % 10 == 0:
			Fx.ring(get_parent(), global_position + Vector2(0, -9), Pal.R if Engine.get_physics_frames() % 20 == 0 else Pal.O, 0.0, 26.0, 0.6, 0.3)
	# el giro del bárbaro: anillo de viento a cada vuelta
	if spin and swing_t < spin_n * SPIN_GAP and not dead:
		var k := _spin_idx()
		if swing_t - k * SPIN_GAP < 0.02:
			var r := 30.0 if evo else 24.0
			Fx.slash(get_parent(), global_position + Vector2(0, -9), r * 0.8, -180.0 + 180.0 * (k % 2), 180.0 + 180.0 * (k % 2), face, _barb_col(), 6.0, SPIN_GAP)
			Fx.dust(get_parent(), global_position, 4, 55.0, 3.0, 1.8, Pal.S)
			# cada barrido: un tirón de cámara para su lado, viento a los costados y brasas que salen despedidas
			var sd := face * (1.0 if k % 2 == 0 else -1.0)
			Fx.shake(2.0, 0.1)
			Fx.kick(Vector2(sd, 0), 1.5)
			for i in 5:
				Fx.streak(get_parent(), global_position + Vector2(sd * randf_range(4, 12), -randf_range(3, 17)),
					Vector2(sd * randf_range(150, 240), randf_range(-12, 12)), 0.14, _barb_col() if i % 2 == 0 else Pal.W, 9.0)
			Fx.burst(get_parent(), global_position + Vector2(sd * r * 0.6, -9), 5, [_barb_col(), Pal.Y, Pal.W], 110.0, 30.0, 0.3, 200.0)
		if Engine.get_physics_frames() % 3 == 0:
			Fx.afterimage(get_parent(), sprite, _barb_col())
	# mago: la gema del bastón suelta brasas (más cuando carga), el doble salto deja fantasmas de su color
	# y cayendo se le escapan chispas del abrigo
	if kind == "mage" and not dead:
		gem_t -= dt
		if gem_t <= 0.0:
			gem_t = 0.05 if charge >= CHG_ON or cast_t > 0.0 else 0.16
			Fx.part(get_parent(), gem_pos() + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)), Vector2(randf_range(-6, 6), -randf_range(10, 24)), -12.0, 0.4, _mage_col(1 + randi() % 2))
		if not is_on_floor() and velocity.y > 40.0 and Engine.get_physics_frames() % 4 == 0:
			Fx.part(get_parent(), global_position + Vector2(-face * randf_range(2, 8), -randf_range(4, 14)), Vector2(-face * 8.0, -randf_range(20, 40)), -10.0, 0.35, _mage_col(1 + randi() % 3))
		if charge >= chg_full() and Engine.get_physics_frames() % 8 == 0:
			Fx.ring(get_parent(), gem_pos(), _mage_col(1), 0.0, 7.0, 1.0, 0.2)
	# evolucionado: chispitas de vez en cuando (doradas; verdes el Nigromante); con veneno, gotitas verdes
	if evo and not dead and randf() < 0.08:
		Fx.part(get_parent(), global_position + Vector2(randf_range(-5, 5), -randf_range(4, 18)), Vector2(0, -14), -10.0, 0.4, (Pal.L if kind == "mage" else Pal.Y) if randf() < 0.6 else Pal.W)
	if venom and not dead and randf() < 0.3:
		Fx.part(get_parent(), global_position + Vector2(face * 8 + randf_range(-2, 2), -11), Vector2(0, -18), -10.0, 0.4, Pal.L if randf() < 0.5 else Pal.G)
