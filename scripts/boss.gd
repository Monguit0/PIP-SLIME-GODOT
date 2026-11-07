class_name Boss
extends Node2D
## El Mega Caballero, jefe del Salón del Trono, con la lógica del juego web (updateBoss/bossTele/bossAct):
## cae del techo, ruge y pelea con cuatro ataques que avisa antes de tirarlos:
## - sweep: barrido de espada al ras del piso (hay que saltarlo o alejarse).
## - slam: salta hacia donde estás y al caer manda ondas de choque por el piso.
## - charge: embestida hasta la pared; si choca queda aturdido (y recibe 50% más de daño).
## - rain: llueven espadas del techo con un hueco de dos lugares para esquivarlas.
## Al 50% se enfurece (repite ataques y los encadena) y al 25% pierde el casco y pelea con todo.
## Se le pega con flechas o pisándole la cabeza. El cuerpo es arte de PixelLab; la espada se dibuja
## en código (como en el original) porque gira con cada ataque.

const BW := 24.0
const BH := 40.0
const MAX_HP := 40
const ARENA_MIN := 1546.0
const ARENA_MAX := 1782.0
const GROUND := 128.0
const SWORD_LEN := 36.0
const HAND := Vector2(6, -15)  # el puño, desde los pies (mirando a la derecha)
const REST := 22.0             # la espada en guardia, apuntando un poco hacia abajo
const DIR := "res://assets/sprites/boss/"
const COMBO := {"charge": "rain", "slam": "sweep", "sweep": "slam", "rain": "charge"}
const TELE := {"sweep": 0.68, "slam": 0.55, "charge": 0.75, "rain": 0.85}
const WaveScript := preload("res://scripts/wave.gd")

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
var boom_t := 0.0
var walking := false
var ven_t := 0.0
var ven_k := 0.0
var clock := 0.0

var sprite: Sprite2D
var target: Area2D
var frames := {}  # "helm"/"bare" -> {"idle": [tex], "walk": [tex...]}


func _ready() -> void:
	z_index = -1
	for look in ["helm", "bare"]:
		frames[look] = {}
		for anim in ["idle", "walk"]:
			var list: Array = []
			var i := 0
			while ResourceLoader.exists("%s%s/%s/frame_%03d.png" % [DIR, look, anim, i]):
				list.append(load("%s%s/%s/frame_%03d.png" % [DIR, look, anim, i]))
				i += 1
			if list.is_empty() and ResourceLoader.exists("%s%s.png" % [DIR, look]):
				list.append(load("%s%s.png" % [DIR, look]))
			frames[look][anim] = list
	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.offset = Vector2(0, -46)  # lienzo de 96: los pies en la fila 93
	sprite.show_behind_parent = true  # la espada (dibujada por este nodo) va adelante
	add_child(sprite)
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


func _face_player() -> void:
	face = -1 if player.global_position.x < cx() else 1


func _lerp(a: float, b: float, k: float) -> float:
	return lerpf(a, b, clampf(k, 0.0, 1.0))


func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)


## el puño de la espada, en coordenadas del mundo
func hand() -> Vector2:
	var breath := _breath()
	return Vector2(cx() + face * HAND.x, y + BH + HAND.y + crouch * 0.6 + breath)


func sword_tip() -> Vector2:
	var a := deg_to_rad(angle)
	return hand() + Vector2(cos(a) * face, sin(a)) * SWORD_LEN


func _breath() -> float:
	if state != "idle":
		return 0.0
	if walking:
		return float(int(clock * 8.0) % 2)
	return 1.0 if sin(clock * 3.0) > 0.3 else 0.0


func _clear_attacks() -> void:
	for n in get_tree().get_nodes_in_group("ondas"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("peligros"):
		n.queue_free()


# ---------------------------------------------------------------- daño

## Lo llaman las flechas (por el Area2D de blanco).
func take_hit(dmg: int, from_dir: int, _how: String = "arrow") -> void:
	damage(dmg, cx() - from_dir * 8.0, y + 14.0)


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
	game.add_score(total * 10)
	Snd.play("metal")
	var at := Vector2(hx, hy)
	if crit:
		Fx.crit(get_parent(), at)
	else:
		Fx.hitstop(0.03)
		Fx.burst(get_parent(), at, 7, [Pal.Y, Pal.W, Pal.S], 70.0, 20.0, 0.35, 240.0)
	Fx.popup(get_parent(), at + Vector2(0, -6), "-%d" % total, Pal.Y if crit else Pal.W)
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
	Fx.ring(get_parent(), Vector2(cx(), y + 12), Pal.R)


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
	for i in 18:
		var c: Color = [Pal.SS, Pal.S, Pal.W, Pal.D][i % 4]
		Fx.part(get_parent(), Vector2(cx() + randf_range(-5, 5), y + 4 + randf_range(-3, 3)),
			Vector2(randf_range(-80, 80) - face * 40.0, -120.0 - randf() * 120.0), 420.0, 0.9, c, 1 if i % 3 != 0 else 2)
	Snd.duck()
	Fx.hitstop(0.3)
	Fx.flash_red = 0.35
	Fx.shake(5.0, 0.6)
	Fx.burst(get_parent(), Vector2(cx(), y + 10), 36, [Pal.R, Pal.O, Pal.Y, Pal.W], 160.0, 40.0, 0.9, 120.0)
	Fx.ring(get_parent(), Vector2(cx(), y + 12), Pal.R)
	Fx.ring(get_parent(), Vector2(cx(), y + 12), Pal.Y, -0.1)


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
	t += dt
	walking = false
	if ven_t > 0.0 and state != "dying" and state != "gone":
		ven_t -= dt
		ven_k -= dt
		if ven_k <= 0.0:
			ven_k = 0.7
			damage(1, cx(), y + 10, false, true)
		if randf() < 0.4:
			Fx.part(get_parent(), Vector2(cx() + randf_range(-10, 10), y + 8 + randf() * 16), Vector2(0, -20), -10.0, 0.5, Pal.L if randf() < 0.5 else Pal.G)
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
			if t > 1.6:
				_to("idle")
				idle_dur = 0.6
		"idle":
			_face_player()
			var dist := player.global_position.x - cx()
			if absf(dist) > 36.0:
				x += signf(dist) * (32.0 if ph2 else 22.0) * dt
				walking = true
			angle = _lerp(angle, REST + sin(clock * 3.0) * 4.0, dt * 6.0)
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
			if t > (stun_dur if stun_dur > 0.0 else (1.0 if ph2 else 1.4)):
				stun_dur = 0.0
				crouch = 0.0
				_to("idle")
				idle_dur = 0.3
		"rage":
			angle = _lerp(angle, -90.0, dt * 6.0)
			crouch = 0.0
			Fx.shake(3.0, 0.05)
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
		player.hurt(cx())


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
	Fx.ring(get_parent(), Vector2(cx(), y + 14), Pal.Y, 0.15)
	Fx.popup(get_parent(), Vector2(cx(), y - 8), "¡COMBO!", Pal.O)


## Aviso: la espada brilla, junta chispas y toma la pose del ataque.
func _tele(dt: float, tm: float) -> void:
	var dur: float = TELE[atk] * tm * (0.55 if quick else 1.0)
	var k := t / dur
	glow = true
	if randf() < 0.6:
		var tip := sword_tip()
		var a := randf() * TAU
		var r := 14.0 + randf() * 8.0
		Fx.part(get_parent(), tip + Vector2(cos(a), sin(a)) * r, -Vector2(cos(a), sin(a)) * r * 4.0, 0.0, 0.22, Pal.C if randf() < 0.5 else Pal.W)
	match atk:
		"sweep":
			angle = _lerp(REST, -165.0, _ease_out(k * 1.3))
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
				Fx.burst(get_parent(), Vector2(cx(), GROUND), 10, [Pal.SS, Pal.S], 70.0, 20.0, 0.4, 220.0)
			"charge":
				vx = face * (285.0 if phase >= 2 else 240.0)
				Snd.play("tajo", {"rate": 0.5, "vary": false})
			"rain":
				_rain_swords()
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
				Fx.burst(get_parent(), Vector2(cx() + face * 32.0, GROUND), 14, [Pal.SS, Pal.S, Pal.W], 90.0, 30.0, 0.45, 240.0)
				_slash_arc()
			if t > 0.04 and t < 0.17 and game.state == "play":
				var hb := Rect2(x + BW - 8, GROUND - 26, 48, 26) if face > 0 else Rect2(x + 8 - 48, GROUND - 26, 48, 26)
				if not player.dead and player.box().intersects(hb):
					player.hurt(cx())
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
				Fx.part(get_parent(), Vector2(cx() - face * 10.0, GROUND - 1), Vector2(-face * 30.0, -20.0), 100.0, 0.3, Pal.SS)
			var wall := (face < 0 and x <= ARENA_MIN + 0.5) or (face > 0 and x >= ARENA_MAX - BW - 0.5)
			if wall:
				vx = 0.0
				Snd.play("metal", {"rate": 0.4, "vary": false})
				Snd.play("clavar", {"rate": 0.5, "vary": false})
				Snd.boom(0.8)
				Fx.shake(5.0, 0.3)
				Fx.hitstop(0.06)
				Fx.burst(get_parent(), Vector2(ARENA_MAX if face > 0 else ARENA_MIN, GROUND - 16), 16, [Pal.SS, Pal.S, Pal.D, Pal.W], 90.0, 40.0, 0.6, 260.0)
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
					Fx.popup(get_parent(), Vector2(cx(), y - 6), "¡MAREADO!", Pal.Y)
		"rain":
			angle = -90.0
			if t > 0.9:
				if rep > 1:
					rep -= 1
					_rain_swords()
					_to("act")
				else:
					_to("rec")
					rec_dur = 0.7


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


func _slam_fx(px: float, mag: float, waves: bool) -> void:
	Snd.boom()
	Snd.play("pisoton", {"rate": 0.5, "vary": false})
	Snd.play("explotar", {"rate": 0.5, "vary": false})
	Fx.shake(mag, 0.4)
	Fx.hitstop(0.05)
	Fx.burst(get_parent(), Vector2(px, GROUND), 22, [Pal.SS, Pal.S, Pal.D, Pal.W], 110.0, 40.0, 0.6, 260.0)
	Fx.ring(get_parent(), Vector2(px, GROUND), Pal.S)
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


## Arco de la espada al barrer (unas chispas en semicírculo adelante).
func _slash_arc() -> void:
	var h := hand()
	for i in 12:
		var a := deg_to_rad(lerpf(-150.0, 40.0, i / 11.0))
		var p := h + Vector2(cos(a) * face, sin(a)) * (SWORD_LEN + 2.0)
		Fx.part(get_parent(), p, Vector2(cos(a) * face, sin(a)) * 40.0, 0.0, 0.18 + i * 0.01, Pal.W if i % 2 == 1 else Pal.C)


func _dying(dt: float) -> void:
	crouch = minf(6.0, t * 3.0)
	angle = _lerp(angle, 100.0, dt * 2.0)
	boom_t -= dt
	if t < 2.3 and boom_t <= 0.0:
		boom_t = 0.16
		var p := Vector2(x + 2 + randf() * (BW - 4), y + randf() * BH)
		Snd.play("explotar", {"rate": 0.6 + randf() * 0.5})
		Fx.burst(get_parent(), p, 12, [Pal.Y, Pal.O, Pal.R, Pal.W], 90.0, 20.0, 0.5, 120.0)
		Fx.shake(3.0, 0.15)
		flash = 0.06
		Fx.ring(get_parent(), p, Pal.O, 0.1)
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
		Fx.burst(get_parent(), c, 50, [Pal.Y, Pal.O, Pal.R, Pal.W, Pal.S], 180.0, 50.0, 1.0, 160.0)
		Fx.burst(get_parent(), c, 12, [Pal.Y, Pal.W], 110.0, 70.0, 1.2, 100.0, 2)
		Fx.ring(get_parent(), c, Pal.W)
		Fx.ring(get_parent(), c, Pal.Y, -0.08)
		Fx.ring(get_parent(), c, Pal.O, -0.16)
		visible = false
		game.boss_defeated(Vector2(cx(), y))


# ---------------------------------------------------------------- dibujo

func _visuals(_dt: float) -> void:
	position = Vector2(roundf(cx() * 2.0) / 2.0, roundf((y + BH) * 2.0) / 2.0)
	if target.monitorable != active():
		target.set_deferred("monitorable", active())
	var look := "bare" if phase >= 3 else "helm"
	var anim := "walk" if walking and frames[look]["walk"].size() > 1 else "idle"
	var list: Array = frames[look][anim]
	if list.is_empty():
		list = frames["helm"]["idle"]
	if not list.is_empty():
		var fps := 9.0 if anim == "walk" else 5.0
		sprite.texture = list[int(clock * fps) % list.size()]
	sprite.flip_h = face < 0
	# respiración, agacharse (la espada baja con el cuerpo) y estirar/aplastar desde los pies
	var down := crouch + _breath()
	sprite.scale = Vector2(0.5 * sx * (1.0 + down * 0.01), 0.5 * sy * (1.0 - down / 44.0))
	var m := Color.WHITE
	if flash > 0.0:
		m = Color(3, 3, 3)
	elif state == "stun":
		m = Color(0.8, 0.8, 0.95)
	elif phase >= 2 and active():
		var k := 0.5 + 0.5 * sin(clock * (10.0 if phase >= 3 else 5.0))
		m = Color(1.0 + 0.25 * k, 1.0 - 0.1 * k, 1.0 - 0.1 * k)
	if ven_t > 0.0 and flash <= 0.0:
		m = m * Color(0.8, 1.15, 0.7)
	sprite.modulate = m
	queue_redraw()


func _draw() -> void:
	if state == "gone":
		return
	# la espada, a medio píxel: mango, guarda dorada y hoja con filo claro (brilla al avisar un ataque)
	var hnd := hand() - position
	var a := deg_to_rad(angle)
	var d := Vector2(cos(a) * face, sin(a))
	var n := Vector2(d.y, -d.x) * face  # hacia "arriba" de la hoja: ahí va el filo con luz
	var blink := glow and int(clock * 20.0) % 2 == 1
	var white := flash > 0.0
	var s := -5.0
	while s <= 0.0:  # mango (con pomo)
		var pommel := s < -4.0
		_px(hnd + d * s, Pal.W if white else (Pal.Y if pommel else Pal.P))
		_px(hnd + d * s + n * 0.5, Pal.W if white else (Pal.O if pommel else Pal.RAMP_P[3]))
		_px(hnd + d * s - n * 0.5, Pal.W if white else (Pal.O if pommel else Pal.RAMP_P[1]))
		_px(hnd + d * s + n * 1.0, Pal.K)
		_px(hnd + d * s - n * 1.0, Pal.K)
		s += 0.5
	_px(hnd + d * -5.5, Pal.K)
	var k := -5.0
	while k <= 5.0:  # guarda dorada
		var end := absf(k) > 4.5
		_px(hnd + d * 0.5 + n * k, Pal.K)
		_px(hnd + d * 1.0 + n * k, Pal.K if end else (Pal.W if white else Pal.RAMP_Y[3]))
		_px(hnd + d * 1.5 + n * k, Pal.K if end else (Pal.W if white else (Pal.Y if absf(k) < 4.0 else Pal.O)))
		_px(hnd + d * 2.0 + n * k, Pal.K if end else (Pal.W if white else Pal.RAMP_Y[1]))
		_px(hnd + d * 2.5 + n * k, Pal.K)
		k += 0.5
	# hoja ancha: filo claro arriba, lomo oscuro abajo, canal en el medio; se afina en la punta
	var edge := Pal.C if blink else Pal.W
	var hi := Pal.W if blink else (Pal.C if glow else Pal.RAMP_S[3])
	var mid := (Pal.W if blink else Pal.C) if glow else Pal.S
	var dark := Pal.C if glow else Pal.SS
	s = 3.0
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
			draw_rect(Rect2(roundf(sp.x * 2.0) / 2.0 - 0.5, roundf(sp.y * 2.0) / 2.0 - 0.5, 1, 1), Pal.Y)
			draw_rect(Rect2(roundf(sp.x * 2.0) / 2.0 - 1.0, roundf(sp.y * 2.0) / 2.0 - 0.25, 2, 0.5), Pal.W)


func _px(p: Vector2, c: Color) -> void:
	var py := roundf(p.y * 2.0) / 2.0
	if py >= GROUND - position.y:  # la punta que entra en el piso no se ve
		return
	draw_rect(Rect2(roundf(p.x * 2.0) / 2.0, py, 0.5, 0.5), c)
