class_name Boss
extends Node2D
## El Mega Caballero, jefe del Salón del Trono, con la lógica del juego web (updateBoss/bossTele/bossAct):
## cae del techo, ruge y pelea con cuatro ataques que avisa antes de tirarlos:
## - sweep: barrido de espada al ras del piso (hay que saltarlo o alejarse).
## - slam: salta hacia donde estás y al caer manda ondas de choque por el piso.
## - charge: embestida hasta la pared; si choca queda aturdido (y recibe 50% más de daño).
## - rain: llueven espadas del techo con un hueco de dos lugares para esquivarlas.
## Al 50% se enfurece (repite ataques y los encadena) y al 25% pierde el casco y pelea con todo.
## Se le pega con flechas o pisándole la cabeza. El cuerpo es arte de PixelLab animado: respira, camina
## (al paso de lo que avanza), embiste corriendo, se marea, cae de rodillas, ruge con el puño en alto y
## salta entero (se agacha, despega, encoge las piernas, levanta la espada, cae con todo y se levanta).
## En el barrido toma la pose del brazo según el ángulo de la espada ("arc": 19 poses del puño, de atrás
## de la cabeza hasta abajo). La espada se dibuja en código (como en el original): sale del puño del
## cuadro que se ve, los dedos se dibujan encima del mango y es firme: va rígida con el brazo; solo
## entre dos poses del salto o del rugido gira rápido y sin pasarse, y al caer el espadazo se clava de golpe.

const BW := 24.0
const BH := 40.0
const MAX_HP := 40
const ARENA_MIN := 1546.0
const ARENA_MAX := 1782.0
const GROUND := 128.0
const SWORD_LEN := 37.0
const ORIGIN := Vector2(72, 118)  # los pies en el lienzo de 144x144 de los cuadros
const ANIMS := ["arc", "jump", "roar", "idle", "walk", "charge", "dazed", "death"]
const LOOPS := ["idle", "walk", "charge", "dazed"]
const FIST_CELL := 14            # cada puño recortado en fist.png (14x14, el puño en el centro)
const WALK_CYCLE := 19.0         # lo que avanza en un ciclo de caminata (dos pasos, medido en los cuadros)
const SPRING := 40.0             # entre dos poses la espada gira rápido y sin pasarse (rad/s)
const ROAR_HOLD := 6             # el cuadro del rugido con el puño bien arriba: ahí se queda quieto
const REST := 22.0             # la espada en guardia, apuntando un poco hacia abajo
const DIR := "res://assets/sprites/boss/"
const COMBO := {"charge": "rain", "slam": "sweep", "sweep": "slam", "rain": "charge"}
const TELE := {"sweep": 0.68, "slam": 0.55, "charge": 0.75, "rain": 0.85}
const WaveScript := preload("res://scripts/wave.gd")

## Puño de la espada en cada cuadro del Mega Caballero (detectado en los cuadros de PixelLab):
## en píxeles del mundo desde los pies, mirando a la derecha. Los genera la herramienta de cuadros.
## ANGS: el ángulo de la espada que va con cada pose (en "arc" elige el cuadro, en "jump" y "roar"
## lo marca el cuadro).
const HANDS := {
	"helm": {
		"arc": [Vector2(-16.5, -37), Vector2(-12, -40), Vector2(-12, -43), Vector2(-9.5, -45), Vector2(-6.5, -46), Vector2(-4.5, -46.5), Vector2(0, -47.5), Vector2(4.5, -47), Vector2(7, -46), Vector2(8.5, -45), Vector2(11.5, -43.5), Vector2(13, -41), Vector2(14, -39), Vector2(15, -37), Vector2(15.5, -34.5), Vector2(15.5, -29), Vector2(15.5, -26.5), Vector2(13.5, -22.5), Vector2(9, -20)],
		"jump": [Vector2(12.5, -38), Vector2(3, -42), Vector2(-7, -40), Vector2(-10.5, -36), Vector2(-6, -45), Vector2(-14.5, -39.5), Vector2(-19, -36.5), Vector2(-11, -42.5), Vector2(12.5, -44.5), Vector2(16, -12), Vector2(15.5, -13), Vector2(14, -17), Vector2(12, -20.5), Vector2(9, -20.5)],
		"roar": [Vector2(10.5, -19.5), Vector2(11, -19.5), Vector2(11, -19), Vector2(11.5, -18.5), Vector2(11, -40.5), Vector2(-0.5, -45.5), Vector2(1.5, -45.5), Vector2(-3.5, -45.5), Vector2(1.5, -45.5), Vector2(-3.5, -45.5), Vector2(1.5, -45.5), Vector2(-4, -45.5)],
		"idle": [Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22), Vector2(10, -22.5)],
		"walk": [Vector2(10, -22), Vector2(10, -21.5), Vector2(10, -21.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22), Vector2(10, -21.5), Vector2(10, -21.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5)],
		"charge": [Vector2(16, -26.5), Vector2(16.5, -28), Vector2(16.5, -29.5), Vector2(16, -30.5), Vector2(16.5, -30.5), Vector2(16.5, -29), Vector2(16.5, -27.5), Vector2(16.5, -28), Vector2(16.5, -29), Vector2(16, -30.5), Vector2(16.5, -30.5), Vector2(16.5, -27.5)],
		"dazed": [Vector2(11, -17.5), Vector2(11, -17.5), Vector2(11.5, -18), Vector2(11.5, -18), Vector2(10, -18.5), Vector2(10, -18), Vector2(10.5, -17.5), Vector2(10, -17.5)],
		"death": [Vector2(10.5, -17), Vector2(10.5, -15), Vector2(10.5, -13.5), Vector2(10, -12.5), Vector2(10, -13), Vector2(10.5, -13), Vector2(11, -13), Vector2(10, -12.5)],
	},
	"bare": {
		"arc": [Vector2(-16, -37.5), Vector2(-13, -42), Vector2(-12, -44.5), Vector2(-8.5, -45), Vector2(-6.5, -47), Vector2(-3.5, -47), Vector2(0, -48), Vector2(4, -47), Vector2(7.5, -47), Vector2(9, -44.5), Vector2(10.5, -45), Vector2(13, -40.5), Vector2(14.5, -39.5), Vector2(15.5, -35), Vector2(16, -35), Vector2(15.5, -28), Vector2(16, -27), Vector2(13.5, -22), Vector2(12, -17.5)],
		"jump": [Vector2(11.5, -37.5), Vector2(4, -42), Vector2(-6, -41.5), Vector2(-11, -36), Vector2(-6, -45.5), Vector2(-16, -40), Vector2(-19.5, -37.5), Vector2(-9.5, -44.5), Vector2(13, -43), Vector2(17, -12), Vector2(15, -12.5), Vector2(14.5, -17), Vector2(11.5, -21), Vector2(9.5, -20.5)],
		"roar": [Vector2(9.5, -18.5), Vector2(10, -18.5), Vector2(11.5, -19), Vector2(11.5, -18), Vector2(11, -40), Vector2(-1.5, -45.5), Vector2(2, -45), Vector2(-3, -45.5), Vector2(1.5, -45), Vector2(-3, -45.5), Vector2(1.5, -45), Vector2(-4, -45)],
		"idle": [Vector2(10, -22), Vector2(10, -22), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -22), Vector2(10, -22), Vector2(10.5, -22), Vector2(10.5, -22), Vector2(10.5, -22)],
		"walk": [Vector2(10.5, -21.5), Vector2(10, -21), Vector2(10, -21.5), Vector2(10.5, -22.5), Vector2(10, -22.5), Vector2(10, -22.5), Vector2(10, -21.5), Vector2(10, -21), Vector2(10, -21), Vector2(10.5, -22.5), Vector2(10.5, -22.5), Vector2(10.5, -22.5)],
		"charge": [Vector2(17, -27), Vector2(17, -28), Vector2(17, -29), Vector2(17, -30.5), Vector2(17, -30.5), Vector2(17, -29), Vector2(17, -27), Vector2(17, -28), Vector2(16.5, -29), Vector2(16.5, -30.5), Vector2(16.5, -30), Vector2(16.5, -28)],
		"dazed": [Vector2(11, -18), Vector2(11.5, -18.5), Vector2(11.5, -18.5), Vector2(11, -18.5), Vector2(10.5, -19), Vector2(10.5, -18.5), Vector2(10.5, -18), Vector2(10.5, -18)],
		"death": [Vector2(10.5, -17), Vector2(10.5, -15), Vector2(10.5, -13.5), Vector2(10, -12.5), Vector2(10, -13), Vector2(10.5, -13), Vector2(11, -13), Vector2(10, -12.5)],
	},
}
const ANGS := {
	"arc": [-165, -153.2, -141.4, -129.5, -117.7, -105.9, -94.1, -82.3, -70.5, -58.6, -46.8, -35, -23.2, -11.4, 0.5, 12.3, 24.1, 35.9, 47.7],
	"jump": [-40, -90, -125, -140, -105, -150, -165, -125, -60, 72, 76, 55, 35, 22],
	"roar": [48, 48, 48, 48, -40, -90, -86, -94, -86, -94, -86, -94],
}

var game  # main.gd
var player: Player

var x := 1720.0          # izquierda de la caja del cuerpo (como B.x del original)
var y := -80.0           # arriba de la caja
var vx := 0.0
var vy := 0.0
var face := -1
var hp := MAX_HP
var max_hp := MAX_HP
var shown_hp := float(MAX_HP)  # la barra blanca que baja atrás de la roja
var show_t := 0.0
var fill := 0.0
var state := "wait"
var t := 0.0
var phase := 1
var flash := 0.0
var sx := 1.0
var sy := 1.0
var angle := 40.0        # ángulo de la espada en grados: 0 al frente, -90 arriba, 90 abajo
var crouch := 0.0
var bag: Array = []
var last := ""
var atk := ""
var next_atk := ""
var rep := 0
var quick := false
var trail_t := 0.0
var bar_shake := 0.0
var idle_dur := 1.0
var target_x := 0.0
var landed := false
var stomp_t := 0.0
var glow := false
var swing_t := -1.0
var swing_fx := false
var rec_dur := 0.6
var stun_dur := 0.0
var parry_stun := false  # lo aturdió el parry del caballero: el espadazo que le pegue mientras tanto es crítico
var boom_t := 0.0
var walking := false
var ven_t := 0.0
var ven_k := 0.0
var burn_t := 0.0  # quemadura del mago
var burn_k := 0.0
var burn_g := false
var clock := 0.0

var sprite: Sprite2D
var target: Area2D
var frames := {}  # "helm"/"bare" -> {"idle": [tex...], "walk": [...], "arc": [...], ...}
var fists := {}   # "helm"/"bare" -> {"idle": textura con los puños recortados, ...}
var fist: Sprite2D  # los dedos, dibujados encima del mango de la espada
var cur_hand := Vector2(10, -22)  # puño del cuadro actual, desde los pies, mirando a la derecha
var sword_ang := 40.0  # el ángulo que se ve (sigue a `angle` o a la pose con un resorte)
var sword_v := 0.0
var pose_ang := 0.0
var has_pose := false
var snap := false   # la espada salta a la pose sin girar (el golpe del espadazo)
var pose_key := ""
var ang_from := REST  # de dónde arrancó la espada al empezar el aviso
var jitter := false  # tiembla todo el cuerpo (el rugido), la espada con él
var order_t := 0.0   # destello de la espada al dar la orden de la lluvia
var walk_dist := 0.0
var tmul := 1.0
var kick := 0.0      # retroceso al recibir un golpe (solo visual)
var kick_dir := 1.0
var last_face := -1


## Todos los cuadros del jefe, para que main.gd los vaya cargando en segundo plano desde el título
## (cargarlos de golpe al entrar al Salón del Trono daba un tirón).
static func asset_paths() -> Array:
	var out: Array = []
	for look in ["helm", "bare"]:
		for anim in ANIMS:
			var i := 0
			while ResourceLoader.exists("%s%s/%s/frame_%03d.png" % [DIR, look, anim, i]):
				out.append("%s%s/%s/frame_%03d.png" % [DIR, look, anim, i])
				i += 1
			var fp := "%s%s/%s/fist.png" % [DIR, look, anim]
			if ResourceLoader.exists(fp):
				out.append(fp)
	return out


func _ready() -> void:
	z_index = -1
	for look in ["helm", "bare"]:
		frames[look] = {}
		fists[look] = {}
		for anim in ANIMS:
			var list: Array = []
			var i := 0
			while ResourceLoader.exists("%s%s/%s/frame_%03d.png" % [DIR, look, anim, i]):
				list.append(load("%s%s/%s/frame_%03d.png" % [DIR, look, anim, i]))
				i += 1
			frames[look][anim] = list
			var fp := "%s%s/%s/fist.png" % [DIR, look, anim]
			fists[look][anim] = load(fp) if ResourceLoader.exists(fp) else null
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = -ORIGIN
	sprite.show_behind_parent = true  # la espada (dibujada por este nodo) va adelante
	add_child(sprite)
	# los dedos van encima del mango: así la espada se ve agarrada y no pegada
	fist = Sprite2D.new()
	fist.centered = false
	fist.region_enabled = true
	add_child(fist)
	# blanco para las flechas
	target = Area2D.new()
	target.collision_layer = 0
	target.set_collision_layer_value(5, true)
	target.collision_mask = 0
	target.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(BW - 6, BH - 4)
	shape.shape = rect
	shape.position = Vector2(0, -(BH - 4) / 2.0)
	target.add_child(shape)
	add_child(target)
	_visuals(0.0)
	sword_ang = pose_ang if has_pose else angle


# ---------------------------------------------------------------- ayudas

func cx() -> float:
	return x + BW / 2.0


func active() -> bool:
	return not state in ["wait", "drop", "roar", "rage", "dying", "gone"]


func body() -> Rect2:
	return Rect2(x + 4, y + 6, BW - 8, BH - 6)


func head() -> Rect2:
	return Rect2(x + 4, y - 1, BW - 8, 10)


func _to(s: String) -> void:
	state = s
	t = 0.0
	if s == "tele":
		ang_from = angle


func _face_player() -> void:
	var f := -1 if player.global_position.x < cx() else 1
	if f != face:
		sx = 0.86  # se da vuelta con un pequeño aplaste
		sy = 1.06
	face = f


func _lerp(a: float, b: float, k: float) -> float:
	return lerpf(a, b, clampf(k, 0.0, 1.0))


func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)


## el puño de la espada, en coordenadas del mundo (sale del cuadro que se está viendo)
func hand() -> Vector2:
	return position + _hand_local()


## el puño respecto de los pies, tal como se dibuja el cuadro (con el estirar/aplastar)
func _hand_local() -> Vector2:
	return Vector2(face * cur_hand.x * sx, cur_hand.y * sy)


func sword_tip() -> Vector2:
	var a := deg_to_rad(sword_ang)
	return hand() + Vector2(cos(a) * face, sin(a)) * SWORD_LEN


func _clear_attacks() -> void:
	for n in get_tree().get_nodes_in_group("ondas"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("peligros"):
		n.queue_free()


# ---------------------------------------------------------------- daño

## Lo llaman las flechas (por el Area2D de blanco).
func take_hit(dmg: int, from_dir: int, _how: String = "arrow") -> void:
	damage(dmg, cx() - from_dir * 8.0, y + 14.0)


## El parry del caballero lo aturde (stunBoss del original): corta el ataque y queda mareado.
func parried(_d: float, _t: float) -> void:
	if state in ["dying", "gone", "wait", "drop", "roar", "rage"]:
		return
	vx = 0.0
	swing_t = -1.0
	landed = true
	next_atk = ""
	rep = 0
	stun_dur = 1.6
	parry_stun = true
	flash = 0.1
	_to("stun")
	Snd.play("metal", {"rate": 0.5, "vary": false})
	Fx.shake(3.0, 0.2)


## El giro del Warlord en furia lo aturde un segundo (warStunBoss del original).
func war_stun() -> void:
	if state in ["dying", "gone", "wait", "drop", "roar", "rage", "stun"]:
		return
	vx = 0.0
	swing_t = -1.0
	landed = true
	next_atk = ""
	rep = 0
	stun_dur = 1.0
	parry_stun = false
	flash = 0.1
	_to("stun")
	Snd.play("metal", {"rate": 0.6, "vary": false})
	Fx.shake(3.0, 0.2)
	Fx.popup(get_parent(), Vector2(cx(), y - 6), "¡ATURDIDO!", Pal.Y, true)


func apply_burn(long: bool = false, green: bool = false) -> void:
	if not active():
		return
	burn_t = maxf(burn_t, 4.8 if long else 2.4)
	burn_g = green
	if burn_k <= 0.0:
		burn_k = 0.8


func apply_venom() -> void:
	if not active():
		return
	ven_t = 3.0
	if ven_k <= 0.0:
		ven_k = 0.7


func damage(dmg: int, hx: float, hy: float, force: bool = false, no_crit: bool = false) -> bool:
	if not active():
		return false
	var crit := not no_crit and (force or Fx.rand_crit())
	var total := dmg * 3 if crit else dmg
	if state == "stun":
		total = ceili(total * 1.5)
	hp = maxi(0, hp - total)
	show_t = 0.45
	bar_shake = 0.2
	flash = 0.07
	kick = minf(1.5, kick + 1.0)
	kick_dir = signf(cx() - hx) if absf(cx() - hx) > 0.5 else float(-face)
	game.add_score(total * 10)
	Snd.play("metal")
	var at := Vector2(hx, hy)
	if crit:
		Fx.crit(get_parent(), at)
	elif no_crit:  # el veneno: solo unas gotitas verdes
		Fx.burst(get_parent(), at, 4, [Pal.L, Pal.G], 50.0, 20.0, 0.3, 120.0)
	else:
		Fx.hitstop(0.03)
		Fx.hit(get_parent(), at, Vector2(kick_dir, 0.0) if hy > y + 2.0 else Vector2(0, 1), Pal.Y)
		Fx.burst(get_parent(), at, 5, [Pal.Y, Pal.W, Pal.S], 80.0, 20.0, 0.3, 240.0)
	Fx.popup(get_parent(), at + Vector2(0, -6), "-%d" % total, Pal.Y if crit else Pal.W, crit)
	if hp <= 0:
		_die()
	elif phase == 1 and hp <= max_hp / 2.0:
		_enrage()
	elif phase == 2 and hp <= max_hp * 0.25:
		_final_rage()
	return true


func _enrage() -> void:
	phase = 2
	_to("rage")
	vx = 0.0
	crouch = 0.0
	_clear_attacks()
	Snd.play("rugido", {"rate": 1.15, "vary": false})
	Snd.duck()
	game.show_banner("¡FURIA!", "EL MEGA CABALLERO SE ENOJA")
	Fx.hitstop(0.25)
	Fx.flash_red = 0.3
	Fx.shake(4.0, 0.5)
	Fx.burst(get_parent(), Vector2(cx(), y + 10), 30, [Pal.R, Pal.O, Pal.Y], 140.0, 40.0, 0.8, 120.0)
	Fx.ring(get_parent(), Vector2(cx(), y + 12), Pal.R, 0.0, 34.0)
	Fx.shock(get_parent(), Vector2(cx(), GROUND), Pal.O, 44.0, 0.45)
	Fx.dust(get_parent(), Vector2(cx(), GROUND), 6, 60.0, 5.0, 3.0)
	for i in 10:
		Fx.part(get_parent(), Vector2(cx() + randf_range(-10, 10), y + randf_range(4, 30)), Vector2(randf_range(-20, 20), -40.0 - randf() * 30.0), -30.0, 0.8, Pal.O if randf() < 0.5 else Pal.Y)


## Tercera fase: el casco sale volando en pedazos.
func _final_rage() -> void:
	phase = 3
	_to("rage")
	vx = 0.0
	crouch = 0.0
	next_atk = ""
	rep = 0
	_clear_attacks()
	game.show_banner("¡SIN CASCO!", "EL MEGA CABALLERO PELEA CON TODO")
	Snd.play("rugido", {"rate": 1.3, "vary": false})
	Snd.play("metal", {"rate": 0.7, "vary": false})
	Snd.play("clavar", {"rate": 0.6, "vary": false})
	# el yelmo vuela en pedazos de metal que rebotan en el piso
	Fx.hit(get_parent(), Vector2(cx() + face * 2.0, y + 6), Vector2(-face, -0.6), Pal.W, true)
	for i in 18:
		var c: Color = [Pal.SS, Pal.S, Pal.W, Pal.D][i % 4]
		Fx.part(get_parent(), Vector2(cx() + randf_range(-5, 5), y + 4 + randf_range(-3, 3)),
			Vector2(randf_range(-80, 80) - face * 40.0, -120.0 - randf() * 120.0), 420.0, 0.9, c, 1 if i % 3 != 0 else 3, 3)
	Snd.duck()
	Fx.hitstop(0.3)
	Fx.flash_red = 0.35
	Fx.shake(5.0, 0.6)
	Fx.burst(get_parent(), Vector2(cx(), y + 10), 36, [Pal.R, Pal.O, Pal.Y, Pal.W], 160.0, 40.0, 0.9, 120.0)
	Fx.ring(get_parent(), Vector2(cx(), y + 12), Pal.R, 0.0, 34.0)
	Fx.ring(get_parent(), Vector2(cx(), y + 12), Pal.Y, -0.1, 28.0)
	Fx.shock(get_parent(), Vector2(cx(), GROUND), Pal.R, 50.0, 0.5)


func _die() -> void:
	_to("dying")
	vx = 0.0
	boom_t = 0.0
	game.gain_xp(40, Vector2(cx(), y))
	_clear_attacks()
	Fx.crit(get_parent(), Vector2(cx(), y + 12))
	Fx.slowmo = 1.2


# ---------------------------------------------------------------- lógica

func _physics_process(dt: float) -> void:
	clock += dt
	var ph2 := phase >= 2
	var tm := 0.6 if phase >= 3 else (0.72 if ph2 else 1.0)
	tmul = tm
	t += dt
	kick = maxf(0.0, kick - dt * 10.0)
	order_t -= dt
	walking = false
	if ven_t > 0.0 and state != "dying" and state != "gone":
		ven_t -= dt
		ven_k -= dt
		if ven_k <= 0.0:
			ven_k = 0.7
			damage(1, cx(), y + 10, false, true)
		if randf() < 0.4:
			Fx.part(get_parent(), Vector2(cx() + randf_range(-10, 10), y + 8 + randf() * 16), Vector2(0, -20), -10.0, 0.5, Pal.L if randf() < 0.5 else Pal.G)
	if burn_t > 0.0 and state != "dying" and state != "gone":
		burn_t -= dt
		burn_k -= dt
		if burn_k <= 0.0:
			burn_k = 0.8
			damage(1, cx(), y + 10, false, true)
		if randf() < 0.55:
			var fc: Color = (Pal.L if randf() < 0.5 else Pal.G) if burn_g else [Pal.Y, Pal.O, Pal.R][randi() % 3]
			Fx.part(get_parent(), Vector2(cx() + randf_range(-10, 10), y + 8 + randf() * 18), Vector2(randf_range(-4, 4), -randf_range(22, 44)), -20.0, 0.4, fc)
	flash -= dt
	bar_shake -= dt
	sx += (1.0 - sx) * minf(1.0, dt * 8.0)
	sy += (1.0 - sy) * minf(1.0, dt * 8.0)
	if shown_hp > hp:
		show_t -= dt
		if show_t <= 0.0:
			shown_hp = maxf(hp, shown_hp - 24.0 * dt)
	glow = false
	# estela fantasma en la embestida
	if state == "act" and atk == "charge":
		trail_t -= dt
		if trail_t <= 0.0:
			trail_t = 0.035
			Fx.ghost(get_parent(), sprite)
	# furia: chispas que le salen del yelmo
	if ph2 and active() and randf() < 0.35:
		Fx.part(get_parent(), Vector2(cx() + face * 3 + randf() * 3, y + 6), Vector2(randf_range(-5, 5), -30.0 - randf() * 20.0), -20.0, 0.4, Pal.Y if randf() < 0.5 else Pal.O)

	match state:
		"wait":
			if t > 0.8:
				_to("drop")
				vy = 0.0
		"drop":
			vy += 1400.0 * dt
			y += vy * dt
			if y >= GROUND - BH:
				y = GROUND - BH
				sx = 1.35
				sy = 0.7
				_slam_fx(cx(), 7.0, false)
				_to("roar")
				Snd.play("rugido", {"vary": false})
				game.show_banner("MEGA CABALLERO", "GUARDIÁN DEL TRONO", true, true)
		"roar":
			fill = minf(1.0, t / 1.1)
			angle = _lerp(40.0, -90.0, t / 0.4)
			if t < 1.0:
				Fx.shake(2.0, 0.05)
			_roar_rings(dt)
			if t > 1.6:
				_to("idle")
				idle_dur = 0.6
		"idle":
			_face_player()
			var dist := player.global_position.x - cx()
			var lowering := absf(angle - REST) > 12.0  # primero baja la espada, después camina
			if absf(dist) > 36.0 and not lowering:
				x += signf(dist) * (32.0 if ph2 else 22.0) * dt
				var step_was := int(walk_dist / WALK_CYCLE * 2.0)
				walk_dist += (32.0 if ph2 else 22.0) * dt
				walking = true
				if int(walk_dist / WALK_CYCLE * 2.0) != step_was:
					_step()
			angle = _lerp(angle, REST, dt * 8.0)
			crouch = 0.0
			if t > idle_dur:
				_choose_attack()
		"tele":
			_tele(dt, tm)
		"act":
			_act(dt)
		"rec":
			angle = _lerp(angle, REST, dt * 4.0)
			crouch = _lerp(crouch, 0.0, dt * 8.0)
			if t > rec_dur:
				if rep > 1:
					rep -= 1
					_face_player()
					target_x = player.global_position.x
					_to("tele")
					quick = true
					Snd.play("alerta", {"rate": 0.75, "vary": false})
				elif next_atk != "":
					_combo_next()
				else:
					quick = false
					_to("idle")
					idle_dur = (0.35 + randf() * 0.3) if ph2 else (0.6 + randf() * 0.4)
		"stun":
			angle = _lerp(angle, 95.0, dt * 8.0)
			crouch = 2.0
			if y < GROUND - BH:  # si lo aturdieron en el aire, cae
				vy += 1400.0 * dt
				y = minf(GROUND - BH, y + vy * dt)
			if t > (stun_dur if stun_dur > 0.0 else (1.0 if ph2 else 1.4)):
				stun_dur = 0.0
				parry_stun = false
				crouch = 0.0
				_to("idle")
				idle_dur = 0.3
		"rage":
			angle = _lerp(angle, -90.0, dt * 6.0)
			crouch = 0.0
			Fx.shake(3.0, 0.05)
			_roar_rings(dt)
			if t > 1.4:
				_to("idle")
				idle_dur = 0.2
				bag = []
		"dying":
			_dying(dt)
	# si lo cortaron en pleno salto, cae solo al piso
	if y < GROUND - BH and not state in ["wait", "drop", "gone"] and not (state == "act" and atk == "slam" and not landed):
		vy = maxf(0.0, vy) + 1400.0 * dt
		y = minf(GROUND - BH, y + vy * dt)
		if y >= GROUND - BH:
			vy = 0.0
			landed = true
	x = clampf(x, ARENA_MIN, ARENA_MAX - BW)
	_contact()
	_visuals(dt)


## Pisotón en el yelmo (le saca 1) o daño por tocarlo.
func _contact() -> void:
	if not active() or game.state != "play" or player.dead:
		return
	var pb := player.box()
	var hd := head()
	if player.velocity.y > 20.0 and player.prev_bottom <= hd.position.y + 4.0 and pb.intersects(hd):
		player.boss_bounce()
		damage(1, player.global_position.x, y)
	elif state != "stun" and pb.intersects(body()) and player.invuln <= 0.0 and player.stomp_inv <= 0.0:
		player.hurt(cx(), 1, self)


func _choose_attack() -> void:
	var dist := absf(player.global_position.x - cx())
	if bag.is_empty():
		bag = ["sweep", "slam", "charge", "rain"]
		bag.shuffle()
	if dist < 50.0 and last != "sweep" and randf() < 0.6:
		atk = "sweep"
	else:
		atk = bag.pop_back()
		if atk == last and not bag.is_empty():
			var other: String = bag.pop_back()
			bag.push_front(atk)
			atk = other
	last = atk
	rep = 2 if phase >= 2 else 1
	# en la furia encadena: al terminar un ataque sigue otro sin descanso
	next_atk = COMBO[atk] if phase >= 2 and randf() < (0.6 if phase >= 3 else 0.4) else ""
	_face_player()
	_to("tele")
	target_x = player.global_position.x
	Snd.play("alerta", {"rate": 0.7, "vary": false})
	if atk == "rain":
		Snd.play("alerta", {"rate": 0.6, "delay": 0.16, "vary": false})


func _combo_next() -> void:
	atk = next_atk
	last = atk
	next_atk = ""
	rep = 1
	quick = true
	_face_player()
	target_x = player.global_position.x
	_to("tele")
	Snd.play("alerta", {"rate": 0.95, "vary": false})
	Snd.play("alerta", {"rate": 1.2, "delay": 0.08, "vary": false})
	flash = 0.06
	Fx.ring(get_parent(), Vector2(cx(), y + 14), Pal.Y, 0.15, 30.0)
	Fx.popup(get_parent(), Vector2(cx(), y - 8), "¡COMBO!", Pal.O, true)


## Aviso: la espada brilla, junta chispas y toma la pose del ataque.
func _tele(dt: float, tm: float) -> void:
	var dur: float = TELE[atk] * tm * (0.55 if quick else 1.0)
	var k := t / dur
	glow = true
	if randf() < 0.6:
		Fx.converge(get_parent(), sword_tip(), 14.0 + randf() * 8.0, Pal.C if randf() < 0.5 else Pal.W, 0.22)
	match atk:
		"sweep":
			angle = _lerp(ang_from, -165.0, _ease_out(k * 1.3))
			crouch = roundf(_lerp(0.0, 2.0, k))
		"slam":
			angle = _lerp(angle, -90.0, dt * 10.0)
			crouch = roundf(_lerp(0.0, 3.0, k))
			target_x = _lerp(target_x, player.global_position.x, dt * 3.0)
		"charge":
			angle = _lerp(angle, 0.0, dt * 10.0)
			crouch = 1.0
			stomp_t -= dt
			if stomp_t <= 0.0:
				stomp_t = 0.18
				Snd.play("pisoton", {"rate": 0.55, "vol": 0.5})
				Fx.shake(1.0, 0.08)
				Fx.burst(get_parent(), Vector2(cx(), GROUND), 4, [Pal.SS, Pal.S], 40.0, 20.0, 0.3, 200.0)
				sy = 0.92
		"rain":
			angle = _lerp(angle, -90.0, dt * 10.0)
			crouch = 0.0
			if randf() < 0.5:
				Fx.part(get_parent(), sword_tip() + Vector2(randf_range(-1.5, 1.5), 0), Vector2(0, -160), 0.0, 0.3, Pal.C)
	if t >= dur:
		_to("act")
		match atk:
			"slam":
				var air := 0.72
				vy = -500.0
				vx = (target_x - cx()) / air
				landed = false
				Snd.play("salto", {"rate": 0.5, "vary": false})
				sx = 0.75
				sy = 1.3
				Fx.burst(get_parent(), Vector2(cx(), GROUND), 6, [Pal.SS, Pal.S], 70.0, 20.0, 0.4, 220.0)
				Fx.dust(get_parent(), Vector2(cx(), GROUND), 6, 50.0, 6.0, 2.8)
				Fx.shock(get_parent(), Vector2(cx(), GROUND), Pal.S, 20.0, 0.3)
			"charge":
				vx = face * (285.0 if phase >= 2 else 240.0)
				Snd.play("tajo", {"rate": 0.5, "vary": false})
			"rain":
				_rain_swords()
				_order()
			"sweep":
				swing_t = 0.0
				swing_fx = false


func _act(dt: float) -> void:
	match atk:
		"sweep":
			swing_t += dt
			angle = _lerp(-165.0, 50.0, _ease_out(swing_t / 0.15))
			crouch = 0.0
			if t > 0.04 and not swing_fx:
				swing_fx = true
				Snd.play("tajo", {"rate": 0.55, "vary": false})
				Snd.play("metal", {"rate": 0.5, "vol": 0.7, "vary": false})
				Fx.shake(3.0, 0.18)
				sx = 1.15
				sy = 0.9
				Fx.burst(get_parent(), Vector2(cx() + face * 32.0, GROUND), 8, [Pal.SS, Pal.S, Pal.W], 90.0, 30.0, 0.45, 240.0)
				Fx.dust(get_parent(), Vector2(cx() + face * 30.0, GROUND), 5, 50.0, 4.0, 2.4, Pal.S, face)
				Fx.kick(Vector2(face, 0), 1.5)
				_slash_arc()
			if t > 0.04 and t < 0.17 and game.state == "play":
				var hb := Rect2(x + BW - 8, GROUND - 26, 48, 26) if face > 0 else Rect2(x + 8 - 48, GROUND - 26, 48, 26)
				if not player.dead and player.box().intersects(hb):
					player.hurt(cx(), 1, self)
			if t > 0.3:
				_to("rec")
				rec_dur = 0.4 if phase >= 2 else 0.6
		"slam":
			if not landed:
				vy += 1400.0 * dt
				x += vx * dt
				y += vy * dt
				angle = -90.0
				if vy > 0.0 and y >= GROUND - BH:
					y = GROUND - BH
					landed = true
					vx = 0.0
					angle = 75.0
					crouch = 3.0
					sx = 1.4
					sy = 0.65
					_slam_fx(cx(), 6.0, true)
					_to("rec")
					rec_dur = 0.45 if phase >= 2 else 0.75
		"charge":
			x += vx * dt
			angle = 0.0
			crouch = 1.0
			if randf() < 0.6:
				Fx.dust(get_parent(), Vector2(cx() - face * 8.0, GROUND), 1, 30.0, 8.0, randf_range(1.6, 2.6), Pal.S, -face)
			if randf() < 0.7:
				Fx.streak(get_parent(), Vector2(cx() - face * randf_range(6.0, 14.0), y + randf_range(4.0, BH - 4.0)),
					Vector2(-face * 260.0, 0.0), 0.14, Pal.W if randf() < 0.4 else Pal.C, 10.0)
			var wall := (face < 0 and x <= ARENA_MIN + 0.5) or (face > 0 and x >= ARENA_MAX - BW - 0.5)
			if wall:
				vx = 0.0
				Snd.play("metal", {"rate": 0.4, "vary": false})
				Snd.play("clavar", {"rate": 0.5, "vary": false})
				Snd.boom(0.8)
				Fx.shake(5.0, 0.3)
				Fx.hitstop(0.06)
				Fx.kick(Vector2(face, 0), 3.0)
				var wp := Vector2(ARENA_MAX if face > 0 else ARENA_MIN, GROUND - 16)
				Fx.hit(get_parent(), wp, Vector2(-face, 0), Pal.W, true)
				Fx.burst(get_parent(), wp, 12, [Pal.SS, Pal.S, Pal.D, Pal.W], 90.0, 40.0, 0.6, 260.0)
				Fx.chunks(get_parent(), wp, 8, [Pal.SS, Pal.S, Pal.D], 110.0, 40.0)
				Fx.dust(get_parent(), Vector2(wp.x, GROUND), 4, 30.0, 4.0, 2.6, Pal.S, -face)
				sx = 0.7
				sy = 1.1
				if rep > 1:
					rep -= 1
					face = -face
					_to("tele")
					quick = true
					Snd.play("alerta", {"rate": 0.75, "vary": false})
				elif next_atk != "":
					_combo_next()
				else:
					quick = false
					_to("stun")
					Fx.popup(get_parent(), Vector2(cx(), y - 6), "¡MAREADO!", Pal.Y, true)
		"rain":
			angle = -90.0
			if t > 0.9:
				if rep > 1:
					rep -= 1
					_rain_swords()
					_order()
					_to("act")
				else:
					_to("rec")
					rec_dur = 0.7


## La orden de la lluvia: la espada en alto destella y el cuerpo se estira; después queda quieta.
func _order() -> void:
	order_t = 0.1
	sx = 0.92
	sy = 1.1
	Fx.ring(get_parent(), sword_tip(), Pal.C, 0.0, 18.0, 1.0, 0.3)
	Fx.twinkle(get_parent(), sword_tip(), Pal.C, 9.0, 0.35)


## Lluvia de espadas: todo el salón menos un hueco de dos lugares.
func _rain_swords() -> void:
	var slots: Array = []
	var sxp := ARENA_MIN + 10.0
	while sxp <= ARENA_MAX - 10.0:
		slots.append(sxp)
		sxp += 28.0
	var gap := randi() % (slots.size() - 1)
	for i in slots.size():
		if i != gap and i != gap + 1:
			game.spawn_hazard(slots[i], i * 0.04, true, 0.85)
	Snd.play("alerta", {"vary": false})
	Snd.play("alerta", {"vary": false, "delay": 0.14, "rate": 1.12})
	Fx.burst(get_parent(), sword_tip(), 10, [Pal.C, Pal.W], 80.0, 80.0, 0.4, 0.0)


## Pisada al caminar (cuadros 0 y 6 de la caminata, cuando apoya el pie de adelante): la bota pesada,
## el tintineo de la armadura y un poco de polvo.
func _step() -> void:
	Snd.play("paso", {"vol": 0.6})
	Fx.dust(get_parent(), Vector2(cx() + face * 6.0, GROUND), 2, 12.0, 2.0, 2.0)


func _slam_fx(px: float, mag: float, waves: bool) -> void:
	Snd.boom()
	Snd.play("pisoton", {"rate": 0.5, "vary": false})
	Snd.play("explotar", {"rate": 0.5, "vary": false})
	Fx.shake(mag, 0.4)
	Fx.hitstop(0.05)
	Fx.burst(get_parent(), Vector2(px, GROUND), 12, [Pal.SS, Pal.S, Pal.D, Pal.W], 110.0, 40.0, 0.6, 260.0)
	Fx.chunks(get_parent(), Vector2(px, GROUND - 1), 10, [Pal.SS, Pal.S, Pal.D], 130.0, 60.0)
	Fx.dust(get_parent(), Vector2(px, GROUND), 10, 80.0, 5.0, 3.2)
	Fx.shock(get_parent(), Vector2(px, GROUND), Pal.W, 46.0, 0.4)
	Fx.shock(get_parent(), Vector2(px, GROUND - 1), Pal.S, 30.0, 0.5)
	if waves:
		var spd := 190.0 if phase >= 2 else 150.0
		_wave(px - 10.0, -1, spd)
		_wave(px + 10.0, 1, spd)
		if phase >= 2:
			_wave(px - 10.0, -1, spd * 0.62)
			_wave(px + 10.0, 1, spd * 0.62)


func _wave(px: float, d: int, spd: float) -> void:
	var w := WaveScript.new()
	w.game = game
	w.dir = d
	w.spd = spd
	w.min_x = ARENA_MIN
	w.max_x = ARENA_MAX
	w.position = Vector2(px, 0)
	w.add_to_group("ondas")
	get_parent().add_child(w)


## Arco de la espada al barrer: media luna con filo blanco, y chispas que salen de la punta.
func _slash_arc() -> void:
	var h := hand()
	Fx.slash(get_parent(), h, SWORD_LEN + 2.0, -160.0, 45.0, face, Pal.C, 8.0, 0.18)
	for i in 6:
		var a := deg_to_rad(lerpf(-120.0, 40.0, i / 5.0))
		var p := h + Vector2(cos(a) * face, sin(a)) * (SWORD_LEN + 2.0)
		Fx.part(get_parent(), p, Vector2(-sin(a) * face, cos(a)) * 90.0, 0.0, 0.2, Pal.W if i % 2 == 1 else Pal.C)


## Ondas que salen de la cabeza mientras ruge.
func _roar_rings(dt: float) -> void:
	for at in [0.42, 0.66, 0.9]:
		if t >= at and t - dt < at:
			var head_at := Vector2(cx() + face * 3.0, y + 8.0)
			Fx.ring(get_parent(), head_at, Pal.W, 0.0, 40.0, 1.0, 0.45)
			Fx.ring(get_parent(), head_at, Pal.R if phase >= 2 else Pal.S, -0.05, 30.0, 1.0, 0.4)


func _dying(dt: float) -> void:
	crouch = minf(6.0, t * 3.0)
	angle = _lerp(angle, 100.0, dt * 2.0)
	boom_t -= dt
	if t < 2.3 and boom_t <= 0.0:
		boom_t = 0.16
		var p := Vector2(x + 2 + randf() * (BW - 4), y + randf() * BH)
		Snd.play("explotar", {"rate": 0.6 + randf() * 0.5})
		Fx.boom(get_parent(), p, randf_range(5.0, 8.0))
		Fx.burst(get_parent(), p, 8, [Pal.Y, Pal.O, Pal.R, Pal.W], 100.0, 20.0, 0.5, 120.0)
		Fx.shake(3.0, 0.15)
		flash = 0.06
	if t > 2.4:
		_to("gone")
		# la espada queda clavada en el piso
		var h = game.spawn_hazard(cx() + face * 10.0, 0.0, true)
		h.phase = "stuck"
		h.y = GROUND - 9.0
		h.life = 6.0
		h.wob = 0.4
		Snd.boom()
		Snd.play("explotar", {"rate": 0.4, "vary": false})
		Snd.play("critico", {"rate": 0.8, "vary": false})
		var c := Vector2(cx(), y + 14)
		Fx.shake(7.0, 0.6)
		Fx.hitstop(0.1)
		Fx.impact(c, 0.1)
		Fx.boom(get_parent(), c, 16.0)
		Fx.chunks(get_parent(), c, 14, [Pal.SS, Pal.S, Pal.W, Pal.D], 160.0, 80.0, GROUND, 1.0, 1.1)
		Fx.dust(get_parent(), Vector2(c.x, GROUND), 10, 90.0, 6.0, 3.5, Pal.S)
		Fx.shock(get_parent(), Vector2(c.x, GROUND), Pal.Y, 70.0, 0.6)
		Fx.burst(get_parent(), c, 40, [Pal.Y, Pal.O, Pal.R, Pal.W, Pal.S], 180.0, 50.0, 1.0, 160.0)
		Fx.burst(get_parent(), c, 12, [Pal.Y, Pal.W], 110.0, 70.0, 1.2, 100.0, 2)
		Fx.ring(get_parent(), c, Pal.W, 0.0, 40.0, 1.0, 0.5)
		Fx.ring(get_parent(), c, Pal.Y, -0.08, 34.0, 1.0, 0.5)
		Fx.ring(get_parent(), c, Pal.O, -0.16, 28.0, 1.0, 0.5)
		visible = false
		game.boss_defeated(Vector2(cx(), y))


# ---------------------------------------------------------------- dibujo

func _visuals(dt: float) -> void:
	var shake := (0.5 if int(clock * 30.0) % 2 == 0 else -0.5) if jitter else 0.0
	position = Vector2(roundf((cx() + kick * kick_dir + shake) * 2.0) / 2.0, roundf((y + BH) * 2.0) / 2.0)
	if target.monitorable != active():
		target.set_deferred("monitorable", active())
	_pick_frame()
	_swing_sword(dt)
	# estirar/aplastar desde los pies; mirando a la izquierda se espeja con la escala
	sprite.scale = Vector2(0.5 * sx * face, 0.5 * sy)
	fist.scale = sprite.scale
	var m := Color.WHITE
	sprite.material = Fx.silhouette(Color.WHITE) if flash > 0.0 else null
	fist.material = sprite.material
	if flash > 0.0:
		m = Color.WHITE
	elif state == "stun":
		m = Color(0.8, 0.8, 0.95)
	elif phase >= 2 and active():
		var k := 0.5 + 0.5 * sin(clock * (10.0 if phase >= 3 else 5.0))
		m = Color(1.0 + 0.25 * k, 1.0 - 0.1 * k, 1.0 - 0.1 * k)
	if ven_t > 0.0 and flash <= 0.0:
		m = m * Color(0.8, 1.15, 0.7)
	elif burn_t > 0.0 and flash <= 0.0:
		m = m * (Color(0.85, 1.2, 0.75) if burn_g else Color(1.25, 0.95, 0.8))
	sprite.modulate = m
	fist.modulate = m
	queue_redraw()


## La espada es firme: va rígida con el brazo (el ángulo que pide el ataque elige la pose del brazo).
## Solo cuando el cuadro marca la pose (salto, rugido) gira hacia ella rápido y sin pasarse, y el
## espadazo al caer se clava de golpe.
func _swing_sword(dt: float) -> void:
	if not has_pose:
		sword_ang = angle
		sword_v = 0.0
		return
	if snap:
		sword_ang = pose_ang
		sword_v = 0.0
	elif dt > 0.0:  # congelado por un golpe fuerte: queda donde está
		var acc := SPRING * SPRING * (pose_ang - sword_ang) - 2.0 * SPRING * sword_v
		sword_v += acc * dt
		sword_ang += sword_v * dt
	angle = sword_ang  # el ataque sigue desde donde quedó la espada


## Elige animación y cuadro según lo que esté haciendo, y guarda dónde quedó el puño.
func _pick_frame() -> void:
	var look := "bare" if phase >= 3 else "helm"
	var anim := "idle"
	var i := 0
	var by_angle := false
	match state:
		"wait", "drop":
			anim = "jump"
			i = 7  # cae del techo con la espada levantada
		"roar", "rage":
			anim = "roar"
			i = _roar_frame()
		"idle":
			if absf(angle - REST) > 12.0:
				anim = "arc"  # viene con la espada alta: la baja con el brazo
				by_angle = true
			elif walking:
				anim = "walk"
				i = int(walk_dist / WALK_CYCLE * 12.0)  # al paso de lo que avanza: los pies no patinan
			else:
				anim = "idle"
				i = int(clock * 8.0)
		"tele", "act":
			match atk:
				"charge":
					anim = "charge"
					# avisando: pisotea en el lugar, un pie en cada pisotón; embistiendo: corre
					i = 6 * (int(t / 0.18) % 2) if state == "tele" else int(clock * 22.0)
				"slam":
					anim = "jump"
					i = _jump_frame()
				"rain":
					anim = "roar"
					# levanta la espada y la deja quieta en alto: la orden y mientras caen las espadas
					i = (4 if t < 0.1 else (5 if t < 0.2 else ROAR_HOLD)) if state == "tele" else ROAR_HOLD
				_:
					anim = "arc"
					by_angle = true
		"rec":
			if atk == "slam":
				anim = "jump"
				i = _land_frame()
			elif absf(angle - REST) < 10.0 and absf(sword_ang - REST) < 14.0:
				anim = "idle"
				i = int(clock * 8.0)
			else:
				anim = "arc"
				by_angle = true
		"stun":
			anim = "dazed"
			i = int(clock * 8.0)
		"dying":
			anim = "death"
			i = int(t / 0.2)
	var list: Array = frames[look].get(anim, [])
	if list.is_empty():
		look = "helm"
		list = frames["helm"].get(anim, [])
	if list.is_empty():
		anim = "idle"
		by_angle = false
		list = frames[look].get("idle", [])
	if list.is_empty():
		return
	var n := list.size()
	var angs: Array = ANGS.get(anim, [])
	if by_angle and angs.size() == n:
		# la pose del brazo que va con el ángulo de la espada (la espada va rígida con él)
		var best := 0
		for k in n:
			if absf(float(angs[k]) - angle) < absf(float(angs[best]) - angle):
				best = k
		i = best
	elif anim in LOOPS:
		i = posmod(i, n)
	else:
		i = clampi(i, 0, n - 1)
	has_pose = not by_angle and angs.size() == n
	if has_pose:
		pose_ang = angs[i]
		if anim == "roar" and i == ROAR_HOLD:
			pose_ang = -90.0  # bien derecha para arriba
	# el espadazo al caer: la espada se clava de golpe, sin girar
	var key := "%s%d" % [anim, i]
	snap = anim == "jump" and i == 9 and key != pose_key
	pose_key = key
	jitter = anim == "roar" and i == ROAR_HOLD and state in ["roar", "rage"]
	sprite.texture = list[i]
	var hs: Array = HANDS.get(look, {}).get(anim, [])
	if i < hs.size():
		cur_hand = hs[i]
	# los dedos: el recorte del puño de este cuadro, en el mismo lugar del lienzo
	var ft: Texture2D = fists.get(look, {}).get(anim)
	fist.visible = ft != null and i < hs.size() and state != "gone"
	if fist.visible:
		fist.texture = ft
		fist.region_rect = Rect2(i * FIST_CELL, 0, FIST_CELL, FIST_CELL)
		fist.offset = -ORIGIN + (ORIGIN + cur_hand * 2.0) - Vector2(FIST_CELL, FIST_CELL) / 2.0


## Salto: se agacha mientras avisa, despega, sube con las piernas encogidas, arriba la espada atrás,
## cae y justo antes de tocar el piso la trae para adelante.
func _jump_frame() -> int:
	if state == "tele":
		var dur: float = TELE["slam"] * tmul * (0.55 if quick else 1.0)
		return 1 + mini(2, int(t / maxf(0.01, dur) * 3.0))
	if landed:
		return 9
	if t < 0.07:
		return 4
	if vy < -230.0:
		return 5
	if vy < 150.0:
		return 6
	if GROUND - BH - y > 26.0:
		return 7
	return 8


## Después del espadazo: agachado con la espada clavada, y se levanta de a poco.
func _land_frame() -> int:
	var k := t / maxf(0.01, rec_dur)
	if k < 0.3:
		return 9
	if k < 0.5:
		return 10
	if k < 0.68:
		return 11
	if k < 0.85:
		return 12
	return 13


## Rugido (entrada y furia): junta fuerza agachado, revienta para arriba y tiembla con el puño en alto.
func _roar_frame() -> int:
	if t < 0.4:
		return int(t / 0.1)
	if t < 0.5:
		return 4
	if t < 0.6:
		return 5
	return ROAR_HOLD


func _draw() -> void:
	if state == "gone":
		return
	# la espada, a medio píxel: mango, guarda dorada y hoja con filo claro (brilla al avisar un ataque).
	# El mango va centrado en el puño (los dedos se dibujan encima) y asoma el pomo por detrás.
	var hnd := _hand_local()
	var a := deg_to_rad(sword_ang)
	var d := Vector2(cos(a) * face, sin(a))
	var n := Vector2(d.y, -d.x) * face  # hacia "arriba" de la hoja: ahí va el filo con luz
	var blink := glow and int(clock * 20.0) % 2 == 1
	var white := flash > 0.0 or order_t > 0.0
	var s := -4.0
	while s <= 1.5:  # mango (con pomo)
		var pommel := s < -3.0
		_px(hnd + d * s, Pal.W if white else (Pal.Y if pommel else Pal.P))
		_px(hnd + d * s + n * 0.5, Pal.W if white else (Pal.O if pommel else Pal.RAMP_P[3]))
		_px(hnd + d * s - n * 0.5, Pal.W if white else (Pal.O if pommel else Pal.RAMP_P[1]))
		_px(hnd + d * s + n * 1.0, Pal.K)
		_px(hnd + d * s - n * 1.0, Pal.K)
		s += 0.5
	_px(hnd + d * -4.5, Pal.K)
	var k := -5.0
	while k <= 5.0:  # guarda dorada
		var end := absf(k) > 4.5
		_px(hnd + d * 1.5 + n * k, Pal.K)
		_px(hnd + d * 2.0 + n * k, Pal.K if end else (Pal.W if white else Pal.RAMP_Y[3]))
		_px(hnd + d * 2.5 + n * k, Pal.K if end else (Pal.W if white else (Pal.Y if absf(k) < 4.0 else Pal.O)))
		_px(hnd + d * 3.0 + n * k, Pal.K if end else (Pal.W if white else Pal.RAMP_Y[1]))
		_px(hnd + d * 3.5 + n * k, Pal.K)
		k += 0.5
	# hoja ancha: filo claro arriba, lomo oscuro abajo, canal en el medio; se afina en la punta
	var edge := Pal.C if blink else Pal.W
	var hi: Color = Pal.W if blink else (Pal.C if glow else Pal.RAMP_S[3])
	var mid := (Pal.W if blink else Pal.C) if glow else Pal.S
	var dark := Pal.C if glow else Pal.SS
	s = 4.0
	while s <= SWORD_LEN:
		var p := hnd + d * s
		var w := 1.5 if s < SWORD_LEN - 4.0 else (1.0 if s < SWORD_LEN - 1.5 else 0.5)
		if white:
			var j := -w
			while j <= w:
				_px(p + n * j, Pal.W)
				j += 0.5
		else:
			_px(p + n * w, Pal.K)
			_px(p - n * w, Pal.K)
			if w >= 1.5:
				_px(p + n * 1.0, edge)
				_px(p + n * 0.5, hi)
				_px(p, mid)
				_px(p - n * 0.5, mid if s < 8.0 else dark)
				_px(p - n * 1.0, dark)
			elif w >= 1.0:
				_px(p + n * 0.5, edge)
				_px(p, mid)
				_px(p - n * 0.5, dark)
			else:
				_px(p, edge)
		s += 0.5
	_px(hnd + d * (SWORD_LEN + 0.5), Pal.K)
	# estrellitas de mareado
	if state == "stun":
		var hp0 := Vector2(0, -BH - 4 + crouch)
		for i in 3:
			var ang := clock * 5.0 + i * TAU / 3.0
			var sp := hp0 + Vector2(cos(ang) * 8.0, sin(ang) * 2.5)
			var big := sin(ang) > 0.0  # adelante se ven más grandes
			var cx0 := roundf(sp.x * 2.0) / 2.0
			var cy0 := roundf(sp.y * 2.0) / 2.0
			var arm := 1.5 if big else 1.0
			draw_rect(Rect2(cx0 - arm, cy0, arm * 2.0 + 0.5, 0.5), Pal.Y)
			draw_rect(Rect2(cx0, cy0 - arm, 0.5, arm * 2.0 + 0.5), Pal.Y)
			draw_rect(Rect2(cx0 - 0.5, cy0 - 0.5, 1.5, 1.5), Pal.RAMP_Y[3] if big else Pal.Y)
			draw_rect(Rect2(cx0, cy0, 0.5, 0.5), Pal.W)


func _px(p: Vector2, c: Color) -> void:
	var py := roundf(p.y * 2.0) / 2.0
	if py >= GROUND - position.y:  # la punta que entra en el piso no se ve
		return
	draw_rect(Rect2(roundf(p.x * 2.0) / 2.0, py, 0.5, 0.5), c)
