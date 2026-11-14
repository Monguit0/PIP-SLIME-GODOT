extends Node2D
## Lo que cae del cielo, con aviso: flechas en las zonas y espadas en la lluvia del Mega Caballero.
## Fases: warn (línea punteada que titila cada vez más rápido) -> fall -> stuck (clavada un rato).
## Si le cae a un slime, lo aplasta. La espada del jefe vencido queda clavada como recuerdo.

const ARROW := preload("res://assets/sprites/items/arrow_down.png")  # 3x8 en el mundo
const SWORD := preload("res://assets/sprites/items/sword_down.png")  # 5x11 en el mundo
const Pix := preload("res://scripts/pix.gd")
const WARN_PATH := "res://assets/sprites/items/warn.png"  # cartelito de peligro (PixelLab), 16x16 HD

static var warn_tex: Texture2D = null

var game  # main.gd
var big := false
var unstoppable := false  # las del castigo del portón: ni el golpe las rompe ni el escudo las frena
var land_y := 128.0
var phase := "warn"
var warn := 1.1
var warn_max := 1.1
var y := -14.0
var vy := 0.0
var life := 0.0
var wob := 0.0
var beeped := false
var t := 0.0


func setup(x: float, landing: float, delay: float = 0.0, is_big: bool = false, warn_t: float = 1.1) -> void:
	position = Vector2(roundf(x), 0)
	land_y = landing
	big = is_big
	warn = warn_t + delay
	warn_max = warn
	beeped = delay > 0.0 or is_big


func box() -> Rect2:
	return Rect2(position.x - 2, y, 5, 11) if big else Rect2(position.x - 1, y, 3, 8)


func _ready() -> void:
	z_index = 3
	if warn_tex == null and ResourceLoader.exists(WARN_PATH):
		warn_tex = load(WARN_PATH)


func _physics_process(dt: float) -> void:
	t += dt
	queue_redraw()
	match phase:
		"warn":
			if not beeped:
				beeped = true
				Snd.play("alerta", {"vary": false})
				Snd.play("alerta", {"vary": false, "delay": 0.14, "rate": 1.12})
			warn -= dt
			if warn <= 0.0:
				phase = "fall"
				y = -14.0
				vy = 260.0
				Snd.play("tajo" if big else "disparo", {"rate": 0.8 if big else 1.5, "vol": 0.5})
		"fall":
			vy += 700.0 * dt
			y += vy * dt
			Fx.part(get_parent(), Vector2(position.x, y), Vector2.ZERO, 0.0, 0.12, Pal.C if big else Pal.SS)
			var b := box()
			for h in get_tree().get_nodes_in_group("heroe"):
				var p := h as Player
				if p != null and not p.dead and p.box().intersects(b) and p.hurt(position.x, 1, self):
					queue_free()
					return
			if phase != "fall":  # la paró el escudo
				return
			for s in get_tree().get_nodes_in_group("enemigos"):
				if s.has_method("hit_rect") and not s.dead and s.spawn <= 0.0 and s.hit_rect().intersects(b):
					s.take_hit(99, 0, "trap")
			if y + b.size.y >= land_y + 2.0:
				y = land_y + 2.0 - b.size.y
				phase = "stuck"
				life = 0.8 if big else 1.4
				wob = 0.3
				Snd.play("clavar", {"vol": 0.9, "rate": 0.7 if big else 1.0})
				Fx.shake(2.0 if big else 1.5, 0.1)
				Fx.burst(get_parent(), Vector2(position.x, land_y), 5, [Pal.SS, Pal.S, Pal.C if big else Pal.O], 45.0, 25.0, 0.35, 220.0)
				Fx.dust(get_parent(), Vector2(position.x, land_y), 2, 18.0, 3.0, 1.4)
				Fx.twinkle(get_parent(), Vector2(position.x, land_y), Pal.C if big else Pal.W, 3.5 if big else 2.5, 0.16)
		"stuck":
			life -= dt
			wob -= dt
			if life <= 0.0:
				queue_free()
		"back":  # el parry la mandó de vuelta para arriba
			vy += 300.0 * dt
			y += vy * dt
			Fx.part(get_parent(), Vector2(position.x, y + 8.0), Vector2.ZERO, 0.0, 0.12, Pal.Y)
			if y < -20.0:
				queue_free()


## Un golpe cuerpo a cuerpo (o el escudo) la parte en el aire: +5.
func smash() -> void:
	if phase != "fall" or unstoppable:
		return
	phase = "gone"
	if game != null:
		game.add_score(5)
	Snd.play("clavar", {"rate": 1.9, "vary": false})
	Fx.hitstop(0.05)
	var at := Vector2(position.x, y + 6.0)
	Fx.burst(get_parent(), at, 10, [Pal.Y, Pal.W], 90.0, 40.0, 0.4, 220.0)
	Fx.popup(get_parent(), at, "+5", Pal.C)
	queue_free()


## El parry del caballero la devuelve para arriba.
func parried(_d: float, _t: float) -> void:
	if phase != "fall":
		return
	phase = "back"
	vy = -430.0
	Fx.twinkle(get_parent(), Vector2(position.x, y + 8.0), Pal.Y, 4.0, 0.16)


## El escudo la frena: se parte.
func blocked(_d: float) -> void:
	smash()


func _draw() -> void:
	if phase == "warn":
		_draw_warn()
		return
	if phase == "stuck" and life < 0.4 and int(life * 20.0) % 2 == 1:
		return
	var wx := 0.0
	if phase == "stuck" and wob > 0.0:
		wx = 1.0 if int(wob * 40.0) % 2 == 1 else -1.0
	var flip := phase == "back"  # devuelta por el parry: sube con la punta para arriba
	if big:
		draw_texture_rect(SWORD, Rect2(-2 + wx, roundf(y) + (11.0 if flip else 0.0), 5, -11 if flip else 11), false, Color(1.0, 0.55, 0.5) if unstoppable else Color.WHITE)
	else:
		draw_texture_rect(ARROW, Rect2(-1 + wx, roundf(y) + (8.0 if flip else 0.0), 3, -8 if flip else 8), false)


## Aviso a medio píxel: un haz finito con chevrones que bajan cada vez más rápido, la mira en el piso
## que se cierra sobre donde va a caer, la sombra que crece y el cartelito de peligro arriba.
func _draw_warn() -> void:
	var k := 1.0 - warn / warn_max
	var ramp: Array = Pal.RAMP_C if big and not unstoppable else Pal.RAMP_R
	var on := int(t * (6.0 + 18.0 * k)) % 2 == 0
	var top := 17.0
	var bottom := land_y - 3.0
	# haz de fondo, tenue
	draw_rect(Rect2(0, top, 1.0, bottom - top), Color(ramp[1], 0.25 + 0.3 * k))
	# chevrones que bajan
	var step := 7.0
	var yy := top + fposmod(t * (18.0 + 50.0 * k), step)
	while yy < bottom:
		var near := (yy - top) / maxf(1.0, bottom - top)
		var c: Color = ramp[3] if on and near > 0.6 else (ramp[2] if on else ramp[1])
		# centrado en x = 0.5, como la flecha que cae
		Pix.dot(self, Vector2(0.0, yy), c)
		Pix.dot(self, Vector2(0.5, yy), c)
		Pix.dot(self, Vector2(-0.5, yy - 0.5), c)
		Pix.dot(self, Vector2(1.0, yy - 0.5), c)
		if big:
			Pix.dot(self, Vector2(-1.0, yy - 1.0), c)
			Pix.dot(self, Vector2(1.5, yy - 1.0), c)
		yy += step
	# sombra que crece y mira que se cierra
	var g := land_y + 0.5
	Pix.disc(self, Vector2(0.5, g), 1.0 + (4.0 if big else 3.0) * k, Color(Pal.K, 0.55), 0.5 + 1.0 * k)
	var rx := (3.0 if big else 2.5) + 8.0 * (1.0 - k) * (1.0 - k)
	var rc: Color = ramp[3] if on else ramp[2]
	Pix.ring(self, Vector2(0.5, g), rx, rc, 0.5, maxf(1.0, rx * 0.32))
	for sx in [-1.0, 1.0]:
		Pix.line(self, Vector2(0.5 + sx * (rx + 1.0), g), Vector2(0.5 + sx * (rx + 2.5), g), rc)
	# cartelito de peligro, que salta con cada pitido
	var bob := -1.0 if on and k < 0.8 else 0.0
	if warn_tex != null:
		if on or k < 0.5:
			draw_texture_rect(warn_tex, Rect2(-3.5, 7.0 + bob, 8, 8), false)
	elif on:
		var tc: Color = ramp[2]
		for i in 6:
			Pix.line(self, Vector2(0.5 - i * 0.5, 7.5 + i * 0.5 * 2.0 + bob), Vector2(0.5 + i * 0.5 - 0.5, 7.5 + i + bob), tc)
		draw_rect(Rect2(0.0, 9.0 + bob, 1.0, 2.0), Pal.W)
		draw_rect(Rect2(0.0, 11.5 + bob, 1.0, 0.5), Pal.W)
