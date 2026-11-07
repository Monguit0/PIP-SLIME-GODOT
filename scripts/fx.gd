extends Node
## Juice: partículas, temblor de cámara, hitstop, cámara lenta, zoom, cuadro de impacto, estelas y textos.
## Se usa como autoload "Fx". Los valores salen del juego web (shake, hitstop, burst, popup, crit).

const CRIT_CHANCE := 0.2
const SLOW := 0.5          # lo que dura la cámara lenta del crítico
const PFONT := preload("res://scripts/ptext.gd")

var shake_amount := 0.0
var shake_time := 0.0
var _hitstop := 0.0
var slowmo := 0.0          # segundos de cámara lenta que quedan (el tiempo va al 30%)
var zoom_t := 0.0          # acercamiento de cámara tras un crítico
var zoom_at := Vector2.ZERO
var impact_t := 0.0        # cuadro de impacto (blanco y negro con rayos)
var impact_at := Vector2.ZERO
var impact_seed := 0.0
var flash_red := 0.0       # pantalla roja al recibir daño
var crit_text_t := -1.0    # cartel ¡CRÍTICO!
var crit_text_at := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(dt: float) -> void:
	var real := dt / maxf(Engine.time_scale, 0.001) if _hitstop <= 0.0 else dt / 0.05
	if get_tree().paused:
		real = dt
	var cam := get_viewport().get_camera_2d()
	if shake_time > 0.0:
		shake_time -= real
		if cam:
			cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
		if shake_time <= 0.0 and cam:
			cam.offset = Vector2.ZERO
			shake_amount = 0.0
	flash_red -= real
	impact_t -= real
	if crit_text_t >= 0.0:
		crit_text_t += real
		if crit_text_t > 1.1:
			crit_text_t = -1.0
	# cámara lenta: el tiempo va al 30% y vuelve de a poco
	if _hitstop <= 0.0 and not get_tree().paused:
		if slowmo > 0.0:
			slowmo -= real
			var k := clampf(slowmo / SLOW, 0.0, 1.0)
			Engine.time_scale = 1.0 - 0.7 * k
		else:
			Engine.time_scale = 1.0
	zoom_t = maxf(0.0, zoom_t - real)  # el acercamiento lo aplica la cámara del nivel (main.gd)


## Al empezar una partida: nada de cámara lenta ni carteles colgados de la anterior.
func reset() -> void:
	shake_amount = 0.0
	shake_time = 0.0
	slowmo = 0.0
	zoom_t = 0.0
	impact_t = 0.0
	flash_red = 0.0
	crit_text_t = -1.0
	Engine.time_scale = 1.0


## Cuadro de impacto: un instante en blanco y negro con rayos que salen del golpe.
func impact(pos: Vector2, time: float = 0.09) -> void:
	impact_t = time
	impact_at = pos
	impact_seed = randf() * 6.0


func shake(amount: float, time: float) -> void:
	shake_amount = maxf(shake_amount if shake_time > 0.0 else 0.0, amount * 0.5)
	shake_time = maxf(shake_time, time)


func hitstop(time: float) -> void:
	if _hitstop > 0.0:
		_hitstop = maxf(_hitstop, time)
		return
	_hitstop = time
	Engine.time_scale = 0.05
	while _hitstop > 0.0:
		await get_tree().process_frame
		_hitstop -= get_process_delta_time() / 0.05 if Engine.time_scale > 0.0 else 0.016
	_hitstop = 0.0
	Engine.time_scale = 1.0


func rand_crit() -> bool:
	return randf() < CRIT_CHANCE


## El golpe crítico: congelado, cámara lenta, zoom, cuadro de impacto, temblor, bombo y chispas.
func crit(parent: Node, pos: Vector2) -> void:
	Snd.play("critico", {"vary": false})
	hitstop(0.13)
	slowmo = SLOW
	zoom_t = 0.55
	zoom_at = pos
	impact_t = 0.09
	impact_at = pos
	impact_seed = randf() * 6.0
	shake(6.0, 0.35)
	Snd.boom()
	Snd.play("explotar", {"rate": 0.62, "vary": false})
	Snd.duck()
	burst(parent, pos, 26, [Pal.Y, Pal.W, Pal.O, Pal.R], 150.0, 40.0, 0.75, 200.0)
	burst(parent, pos, 7, [Pal.Y, Pal.W], 90.0, 60.0, 0.9, 120.0, 2)
	ring(parent, pos, Pal.W)
	ring(parent, pos, Pal.Y, -0.06)
	crit_text_t = 0.0
	crit_text_at = pos


## Chispas que salen para todos lados (up = empuje extra hacia arriba).
func burst(parent: Node, pos: Vector2, n: int, colors: Array, speed: float, up: float, life: float = 0.35,
		grav: float = 220.0, size: int = 1) -> void:
	if parent == null:
		return
	for i in n:
		var p := Particle.new()
		p.position = pos
		p.color = colors[randi() % colors.size()]
		var ang := randf() * TAU
		p.vel = Vector2(cos(ang), sin(ang)) * speed * randf_range(0.4, 1.0) + Vector2(0, -up)
		p.life = life * randf_range(0.6, 1.2)
		p.grav = grav
		p.size = size + (1 if randf() < 0.3 else 0)
		parent.add_child(p)


## Una partícula suelta (humo, estelas, brasas).
func part(parent: Node, pos: Vector2, vel: Vector2, grav: float, life: float, color: Color, size: int = 1) -> void:
	if parent == null:
		return
	var p := Particle.new()
	p.position = pos
	p.vel = vel
	p.grav = grav
	p.life = life
	p.color = color
	p.size = size
	parent.add_child(p)


func ring(parent: Node, pos: Vector2, color: Color, delay: float = 0.0) -> void:
	if parent == null:
		return
	var r := Ring.new()
	r.position = pos
	r.color = color
	r.t = delay
	parent.add_child(r)


## Estela fantasma de un Sprite2D (la embestida del jefe).
func ghost(parent: Node, src: Sprite2D) -> void:
	if parent == null or src.texture == null:
		return
	var s := Sprite2D.new()
	s.texture = src.texture
	s.centered = src.centered
	s.offset = src.offset
	s.flip_h = src.flip_h
	s.scale = src.scale
	s.global_position = src.global_position
	s.z_index = -2
	s.modulate = Color(0.5, 0.8, 1.0, 0.45)
	parent.add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.0, 0.25)
	t.tween_callback(s.queue_free)


func afterimage(parent: Node, src: AnimatedSprite2D) -> void:
	var s := Sprite2D.new()
	s.texture = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	s.offset = src.offset
	s.flip_h = src.flip_h
	s.scale = src.scale
	s.global_position = src.global_position
	s.modulate = Color(0.5, 0.8, 1.0, 0.5)
	parent.add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.0, 0.2)
	t.tween_callback(s.queue_free)


## Texto que sube y se desvanece, con la fuente del juego.
func popup(parent: Node, pos: Vector2, text: String, color: Color) -> void:
	if parent == null:
		return
	var l := PopText.new()
	l.text = text
	l.color = color
	l.position = pos
	parent.add_child(l)


class PopText extends Node2D:
	var text := ""
	var color := Color.WHITE
	var t := 0.0

	func _ready() -> void:
		z_index = 50

	func _process(dt: float) -> void:
		t += dt
		if t >= 0.8:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := minf(1.0, t / 0.35)
		var y := -10.0 * (1.0 - pow(1.0 - k, 3.0))
		var a := 1.0 if t < 0.55 else clampf(1.0 - (t - 0.55) / 0.25, 0.0, 1.0)
		PText.draw(self, text, 0, y - 3, Color(color, a), 1, 1)


class Particle extends Node2D:
	var vel := Vector2.ZERO
	var color := Color.WHITE
	var life := 0.35
	var grav := 220.0
	var size := 1
	var t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(dt: float) -> void:
		t += dt
		vel.y += grav * dt
		position += vel * dt
		if position.y > 127.0 and vel.y > 0.0 and grav > 0.0:  # rebota en el piso
			position.y = 127.0
			vel.y *= -0.3
			vel.x *= 0.6
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 - t / life
		var s := float(size) * (0.5 if k < 0.35 else 1.0)
		draw_rect(Rect2(-s / 2.0, -s / 2.0, s, s), Color(color, minf(1.0, k * 2.0)))


class Ring extends Node2D:
	var color := Color.WHITE
	var t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(dt: float) -> void:
		t += dt
		if t > 0.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < 0.0:
			return
		var r := 2.0 + t * 55.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color(color, 1.0 - t / 0.4), 1.0)
