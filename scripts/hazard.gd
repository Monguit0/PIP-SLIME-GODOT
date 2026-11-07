extends Node2D
## Lo que cae del cielo, con aviso: flechas en las zonas y espadas en la lluvia del Mega Caballero.
## Fases: warn (línea punteada que titila cada vez más rápido) -> fall -> stuck (clavada un rato).
## Si le cae a un slime, lo aplasta. La espada del jefe vencido queda clavada como recuerdo.

const ARROW := preload("res://assets/sprites/items/arrow_down.png")  # 3x8 en el mundo
const SWORD := preload("res://assets/sprites/items/sword_down.png")  # 5x11 en el mundo

var game  # main.gd
var big := false
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
			var p: Player = game.player if game != null else null
			if p != null and not p.dead and p.box().intersects(b) and p.hurt(position.x):
				queue_free()
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


func _draw() -> void:
	if phase == "warn":
		var k := 1.0 - warn / warn_max
		var on := int(t * (6.0 + 18.0 * k)) % 2 == 0
		var c := (Pal.C if big else Pal.R) if on else Pal.P
		var yy := 18.0 + int(t * 30.0) % 4
		while yy < land_y - 6.0:
			draw_rect(Rect2(0, yy, 1, 2), c)
			yy += 4.0
		var sw := 2.0 + roundf(6.0 * k)
		draw_rect(Rect2(-sw, land_y - 1, sw * 2 + 1, 1), Pal.K)
		return
	if phase == "stuck" and life < 0.4 and int(life * 20.0) % 2 == 1:
		return
	var wx := 0.0
	if phase == "stuck" and wob > 0.0:
		wx = 1.0 if int(wob * 40.0) % 2 == 1 else -1.0
	if big:
		draw_texture_rect(SWORD, Rect2(-2 + wx, roundf(y), 5, 11), false)
	else:
		draw_texture_rect(ARROW, Rect2(-1 + wx, roundf(y), 3, 8), false)
