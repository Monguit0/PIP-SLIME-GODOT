extends Node
## Juice: partículas, temblor y empujón de cámara, hitstop, cámara lenta, zoom, cuadro de impacto,
## estelas y textos. Se usa como autoload "Fx".
##
## Todo se dibuja a medio píxel, el mismo píxel de los sprites HD, y con las rampas de color de Pal:
## - las chispas nacen blancas y se enfrían por la rampa de su color, con estela según la velocidad;
## - el polvo son bollitos sombreados (luz arriba, sombra abajo) que crecen, frenan y se deshacen;
## - los cascotes y huesitos rebotan en el piso y parpadean antes de irse;
## - el slime salpica gotas que quedan como manchitas, y deja un charco que se seca;
## - los golpes tienen su estrella (destello blanco, rayos y puntas que se apagan), los tajos su media
##   luna, las explosiones su bola de fuego, y los anillos son de píxeles (o aplastados en el piso).
## En las ráfagas, los colores de tierra y piedra (EARTH) salen como polvo y cascotes y el resto como
## chispas, así que los llamados de siempre ya se ven con el estilo nuevo.

const CRIT_CHANCE := 0.2
const SLOW := 0.5          # lo que dura la cámara lenta del crítico
const Pix := preload("res://scripts/pix.gd")
const FLOOR := 127.0
const EARTH := [Pal.S, Pal.SS, Pal.D, Color("c8b090"), Color("#24496d"), Color("#6d6d92"), Color("#49496d")]
const SIL_CODE := "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(1.0);\nvoid fragment() {\n\tCOLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * COLOR.a * tint.a);\n}\n"

var shake_amount := 0.0
var shake_time := 0.0
var shake_len := 0.0
var kick_off := Vector2.ZERO  # empujón de cámara (vuelve solo)
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
var _sil := {}             # color -> ShaderMaterial de silueta
var _sil_shader: Shader


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(dt: float) -> void:
	var real := dt / maxf(Engine.time_scale, 0.001) if _hitstop <= 0.0 else dt / 0.05
	if get_tree().paused:
		real = dt
	var off := Vector2.ZERO
	if shake_time > 0.0:
		shake_time -= real
		var k := clampf(shake_time / maxf(shake_len, 0.001), 0.0, 1.0)
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount * (0.3 + 0.7 * k)
		if shake_time <= 0.0:
			shake_amount = 0.0
	kick_off *= exp(-real * 14.0)
	if kick_off.length() < 0.1:
		kick_off = Vector2.ZERO
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam.offset = Pix.snapv(off + kick_off)
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
	shake_len = 0.0
	kick_off = Vector2.ZERO
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


## Temblor que arranca fuerte y se va apagando.
func shake(amount: float, time: float) -> void:
	shake_amount = maxf(shake_amount if shake_time > 0.0 else 0.0, amount * 0.5)
	shake_time = maxf(shake_time, time)
	shake_len = shake_time


## Empujón de cámara hacia un lado (retroceso del arco, un golpe que entra, el jefe que choca).
func kick(dir: Vector2, amount: float) -> void:
	if dir.length() < 0.01:
		return
	kick_off = (kick_off + dir.normalized() * amount).limit_length(4.0)


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


## Material que pinta el sprite de un solo color (destello blanco al recibir un golpe, estelas).
func silhouette(c: Color) -> ShaderMaterial:
	var key := c.to_html()
	if _sil.has(key):
		return _sil[key]
	if _sil_shader == null:
		_sil_shader = Shader.new()
		_sil_shader.code = SIL_CODE
	var m := ShaderMaterial.new()
	m.shader = _sil_shader
	m.set_shader_parameter("tint", c)
	_sil[key] = m
	return m


## Compila de entrada lo que se dibuja por primera vez en medio de la partida: la silueta del destello
## y de las estelas del dash, y los modos de dibujo de polígonos y líneas. En el renderer Compatibility
## cada shader se compila la primera vez que sale en pantalla, y eso daba un tirón en el primer dash.
func warm(parent: Node, at: Vector2) -> void:
	for m in [null, silhouette(Color.WHITE)]:
		var w := Warmer.new()
		w.position = at
		w.material = m
		parent.add_child(w)


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
	hit(parent, pos, Vector2.RIGHT.rotated(randf_range(-0.4, 0.4)), Pal.Y, true)
	burst(parent, pos, 22, [Pal.Y, Pal.W, Pal.O, Pal.R], 170.0, 40.0, 0.7, 200.0)
	burst(parent, pos, 7, [Pal.Y, Pal.W], 90.0, 60.0, 0.9, 120.0, 2)
	ring(parent, pos, Pal.W, 0.0, 28.0)
	ring(parent, pos, Pal.Y, -0.06, 20.0)
	crit_text_t = 0.0
	crit_text_at = pos


## Ráfaga para todos lados (up = empuje extra hacia arriba). Los colores de tierra y piedra salen
## como polvo y cascotes; los demás como chispas y puntitos.
func burst(parent: Node, pos: Vector2, n: int, colors: Array, speed: float, up: float, life: float = 0.35,
		grav: float = 220.0, size: int = 1) -> void:
	if parent == null or colors.is_empty():
		return
	for i in n:
		var c: Color = colors[randi() % colors.size()]
		var ang := randf() * TAU
		var v := Vector2(cos(ang), sin(ang)) * speed * randf_range(0.4, 1.0) + Vector2(0, -up)
		var p := Particle.new()
		p.position = pos
		p.color = c
		p.life = life * randf_range(0.6, 1.2)
		p.grav = grav
		if c in EARTH:
			if randf() < 0.55:
				p.kind = Particle.DUST
				p.vel = v * 0.4
				p.drag = 5.0
				p.grav = -10.0
				p.life *= 1.5
				p.size = randf_range(1.2, 2.4) * (1.0 + 0.4 * (size - 1))
			else:
				p.kind = Particle.CHUNK
				p.vel = v
				p.size = 1.0 if randf() < 0.6 else 1.5
		else:
			p.kind = Particle.SPARK if randf() < 0.7 else Particle.DOT
			p.vel = v
			p.drag = 1.5
			p.size = 0.5 * (size + (1 if randf() < 0.35 else 0))
		parent.add_child(p)


## Una partícula suelta (humo, estelas, brasas). kind -1 la elige sola: tierra que se mueve es polvo
## (o cascote si cae pesada), lo que sube es brasa, lo rápido chispa y lo quieto un puntito.
func part(parent: Node, pos: Vector2, vel: Vector2, grav: float, life: float, color: Color, size: int = 1,
		kind: int = -1) -> void:
	if parent == null:
		return
	var p := Particle.new()
	p.position = pos
	p.vel = vel
	p.grav = grav
	p.life = life
	p.color = color
	p.size = 0.5 * size
	if kind < 0:
		if color in EARTH and grav >= 200.0:
			kind = Particle.CHUNK
		elif color in EARTH and vel.length() > 5.0:
			kind = Particle.DUST
		elif grav < 0.0:
			kind = Particle.EMBER
		elif vel.length() > 25.0:
			kind = Particle.SPARK
		else:
			kind = Particle.DOT
	p.kind = kind
	if kind == Particle.DUST:
		p.size = 1.0 + 0.6 * size
		p.drag = 3.0
		p.grav = minf(grav, -6.0)
	elif kind == Particle.CHUNK:
		p.size = 1.0 if size <= 1 else 1.5
	parent.add_child(p)


## Bollitos de polvo al saltar, aterrizar, frenar o arrastrarse. dir 0: mitad a cada lado.
func dust(parent: Node, pos: Vector2, n: int, spread: float = 30.0, up: float = 6.0, size: float = 2.0,
		color: Color = Pal.S, dir: float = 0.0) -> void:
	if parent == null:
		return
	for i in n:
		var p := Particle.new()
		p.kind = Particle.DUST
		var sx := dir if dir != 0.0 else (-1.0 if i % 2 == 0 else 1.0)
		p.position = pos + Vector2(randf_range(-1.5, 1.5), randf_range(-0.5, 0.0))
		p.vel = Vector2(sx * spread * randf_range(0.5, 1.1), -up * randf_range(0.4, 1.2))
		p.drag = 6.0
		p.grav = -6.0
		p.life = randf_range(0.35, 0.6)
		p.size = size * randf_range(0.75, 1.2)
		p.color = color
		parent.add_child(p)


## Cascotes, astillas o huesitos que saltan y rebotan (floor_y: dónde rebotan).
func chunks(parent: Node, pos: Vector2, n: int, colors: Array, speed: float, up: float,
		floor_y: float = FLOOR, size: float = 1.0, life: float = 0.7) -> void:
	if parent == null or colors.is_empty():
		return
	for i in n:
		var p := Particle.new()
		p.kind = Particle.CHUNK
		p.position = pos + Vector2(randf_range(-2, 2), randf_range(-2, 1))
		var ang := randf_range(-PI, 0.0)
		p.vel = Vector2(cos(ang), sin(ang)) * speed * randf_range(0.4, 1.0) + Vector2(0, -up)
		p.grav = 420.0
		p.life = life * randf_range(0.7, 1.2)
		p.size = size if randf() < 0.6 else size + 0.5
		p.floor_y = floor_y
		p.color = colors[randi() % colors.size()]
		parent.add_child(p)


## Gotas de slime: vuelan, caen y quedan un ratito como manchita en el piso.
func goo(parent: Node, pos: Vector2, n: int, color: Color, speed: float, floor_y: float = FLOOR) -> void:
	if parent == null:
		return
	for i in n:
		var p := Particle.new()
		p.kind = Particle.GOO
		p.position = pos + Vector2(randf_range(-2, 2), randf_range(-1, 1))
		var ang := randf_range(-PI * 0.95, -PI * 0.05)
		p.vel = Vector2(cos(ang), sin(ang)) * speed * randf_range(0.35, 1.0)
		p.grav = 380.0
		p.life = randf_range(0.7, 1.1)
		p.size = 1.0 if randf() < 0.6 else 1.5
		p.floor_y = floor_y
		p.color = color
		parent.add_child(p)


## Charco del slime reventado: queda en el piso y se seca de afuera hacia adentro.
func splat(parent: Node, pos: Vector2, color: Color, w: float = 9.0) -> void:
	if parent == null:
		return
	var s := Splat.new()
	s.position = Pix.snapv(pos)
	s.color = color
	s.w = w
	parent.add_child(s)


## Estrella de golpe: destello blanco, rayos hacia donde iba el golpe y chispas que siguen de largo.
func hit(parent: Node, pos: Vector2, dir: Vector2, color: Color = Pal.Y, big: bool = false) -> void:
	if parent == null:
		return
	var s := Star.new()
	s.position = Pix.snapv(pos)
	s.dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	s.color = color
	s.big = big
	s.size = 8.0 if big else 5.5
	parent.add_child(s)
	for i in (6 if big else 3):
		var a := s.dir.angle() + randf_range(-0.75, 0.75)
		var p := Particle.new()
		p.kind = Particle.SPARK
		p.position = pos
		p.vel = Vector2.from_angle(a) * randf_range(90.0, 170.0) * (1.25 if big else 1.0)
		p.drag = 4.0
		p.grav = 160.0
		p.life = randf_range(0.18, 0.3)
		p.color = color
		parent.add_child(p)


## Destello de cuatro puntas (monedas, la carga lista, la orden del jefe).
func twinkle(parent: Node, pos: Vector2, color: Color = Pal.Y, size: float = 4.0, life: float = 0.28) -> void:
	if parent == null:
		return
	var s := Star.new()
	s.position = Pix.snapv(pos)
	s.color = color
	s.twinkle = true
	s.size = size
	s.life = life
	parent.add_child(s)


## Media luna del tajo: de a0 a a1 grados alrededor de center (face espeja), con el filo blanco.
func slash(parent: Node, center: Vector2, r: float, a0: float, a1: float, face: float,
		color: Color = Pal.C, width: float = 6.0, life: float = 0.16) -> void:
	if parent == null:
		return
	var s := Smear.new()
	s.position = Pix.snapv(center)
	s.r = r
	s.a0 = a0
	s.a1 = a1
	s.face = face
	s.color = color
	s.width = width
	s.life = life
	parent.add_child(s)


## Explosión: bola blanca, después amarilla y naranja que se abre en anillo, humo y brasas.
func boom(parent: Node, pos: Vector2, r: float = 7.0) -> void:
	if parent == null:
		return
	var b := Boom.new()
	b.position = Pix.snapv(pos)
	b.r = r
	parent.add_child(b)
	for i in roundi(r * 0.6):
		var p := Particle.new()
		p.kind = Particle.DUST
		p.position = pos + Vector2(randf_range(-r, r), randf_range(-r, r)) * 0.5
		p.vel = Vector2(randf_range(-20, 20), randf_range(-30, -10))
		p.drag = 3.0
		p.grav = -20.0
		p.life = randf_range(0.5, 0.8)
		p.size = r * randf_range(0.3, 0.45)
		p.color = Pal.D if randf() < 0.6 else Pal.SS
		p.delay = 0.12
		parent.add_child(p)
	for i in roundi(r * 0.8):
		part(parent, pos, Vector2.from_angle(randf() * TAU) * randf_range(40.0, 120.0) + Vector2(0, -30),
			-40.0, randf_range(0.4, 0.8), Pal.Y if randf() < 0.5 else Pal.O, 1, Particle.EMBER)


## Estela recta (líneas de velocidad, viento): una chispa estirada que no cae.
func streak(parent: Node, pos: Vector2, vel: Vector2, life: float, color: Color, maxlen: float = 8.0) -> void:
	if parent == null:
		return
	var p := Particle.new()
	p.kind = Particle.SPARK
	p.position = pos
	p.vel = vel
	p.grav = 0.0
	p.drag = 6.0
	p.life = life
	p.color = color
	p.stretch = 0.06
	p.maxlen = maxlen
	parent.add_child(p)


## Chispitas que se juntan hacia un punto (carga del arco, aviso del jefe).
func converge(parent: Node, at: Vector2, r: float, color: Color, life: float = 0.22) -> void:
	if parent == null:
		return
	var a := randf() * TAU
	var d := Vector2(cos(a), sin(a))
	var p := Particle.new()
	p.kind = Particle.SPARK
	p.position = at + d * r
	p.vel = -d * r / life
	p.grav = 0.0
	p.life = life
	p.color = color
	p.stretch = 0.03
	parent.add_child(p)


func ring(parent: Node, pos: Vector2, color: Color, delay: float = 0.0, r: float = 24.0, flat: float = 1.0,
		life: float = 0.4) -> void:
	if parent == null:
		return
	var o := Ring.new()
	o.position = Pix.snapv(pos)
	o.color = color
	o.t = delay
	o.rmax = r
	o.flat = flat
	o.life = life
	parent.add_child(o)


## Onda aplastada en el piso (caídas fuertes, el pisotón del jefe).
func shock(parent: Node, pos: Vector2, color: Color = Pal.W, r: float = 26.0, life: float = 0.35) -> void:
	ring(parent, pos, color, 0.0, r, 0.26, life)


## Estela fantasma de un Sprite2D (la embestida del jefe): silueta de color que se apaga.
func ghost(parent: Node, src: Sprite2D, tint: Color = Pal.B) -> void:
	if parent == null or src.texture == null:
		return
	var s := Sprite2D.new()
	s.texture = src.texture
	s.centered = src.centered
	s.offset = src.offset
	s.flip_h = src.flip_h
	s.region_enabled = src.region_enabled
	s.region_rect = src.region_rect
	s.scale = src.scale
	s.global_position = src.global_position
	s.z_index = -2
	s.material = silhouette(tint)
	s.modulate = Color(1, 1, 1, 0.55)
	parent.add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.0, 0.25)
	t.tween_callback(s.queue_free)


func afterimage(parent: Node, src: AnimatedSprite2D, tint: Color = Pal.C) -> void:
	if parent == null:
		return
	var s := Sprite2D.new()
	s.texture = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	s.offset = src.offset
	s.flip_h = src.flip_h
	s.scale = src.scale
	s.global_position = src.global_position
	s.global_rotation = src.global_rotation
	s.material = silhouette(tint)
	s.modulate = Color(1, 1, 1, 0.6)
	parent.add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.0, 0.2)
	t.tween_callback(s.queue_free)


## Texto que salta, sube y se apaga titilando, con borde oscuro (big: más grande y con degradé).
func popup(parent: Node, pos: Vector2, text: String, color: Color, big: bool = false) -> void:
	if parent == null:
		return
	var l := PopText.new()
	l.text = text
	l.color = color
	l.big = big
	l.position = pos
	parent.add_child(l)


class PopText extends Node2D:
	const PX := preload("res://scripts/pix.gd")
	const OUTLINE := [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0, -0.5), Vector2(0, 0.5), Vector2(0.5, 0.5)]
	var text := ""
	var color := Color.WHITE
	var big := false
	var t := 0.0
	var drift := 0.0

	func _ready() -> void:
		z_index = 50
		drift = randf_range(-3.0, 3.0)

	func _process(dt: float) -> void:
		t += dt
		if t >= 0.85:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t > 0.6 and int(t * 20.0) % 2 == 1:
			return  # titila antes de irse
		var k := minf(1.0, t / 0.32)
		var y := -11.0 * (1.0 - pow(1.0 - k, 3.0))
		if t < 0.1:
			y -= 2.0 * sin(t / 0.1 * PI)  # saltito de entrada
		var x := PX.snap(drift * k)
		y = PX.snap(y)
		var c := Color.WHITE if t < 0.05 else color
		if big and text.length() <= 5:  # números grandes con degradé (críticos, +1000)
			var rmp: Array = PX.tone(color)[0]
			PText.draw(self, text, x, y - 5.0, c, 2, 1, Pal.K, [] if t < 0.05 else rmp)
			return
		var ol: Color = PX.shade(color, -2) if big else Pal.K  # las palabras importantes: borde de su color
		for o in OUTLINE:
			PText.draw(self, text, x + o.x, y - 3.0 + o.y, ol, 1, 1, Color(0, 0, 0, 0))
		if big:
			PText.draw(self, text, x + 0.5, y - 2.0, Pal.K, 1, 1, Color(0, 0, 0, 0))
		PText.draw(self, text, x, y - 3.0, c, 1, 1, Color(0, 0, 0, 0))


## Partícula a medio píxel. Las chispas se estiran según la velocidad y se enfrían por la rampa de su
## color; el polvo es un bollito sombreado que crece y se deshace; los cascotes rebotan y parpadean;
## las gotas de slime caen y quedan como manchita; las brasas suben titilando.
class Particle extends Node2D:
	const PX := preload("res://scripts/pix.gd")
	const SPARK := 0
	const DOT := 1
	const DUST := 2
	const CHUNK := 3
	const GOO := 4
	const EMBER := 5

	var kind := 1
	var vel := Vector2.ZERO
	var color := Color.WHITE
	var life := 0.35
	var grav := 220.0
	var drag := 0.0
	var size := 0.5          # lado (o radio, en el polvo) en píxeles lógicos
	var floor_y := 127.0     # dónde rebota
	var stretch := 0.035     # largo de la estela de las chispas por unidad de velocidad
	var maxlen := 3.0
	var delay := 0.0         # tarda en aparecer (el humo de las explosiones)
	var t := 0.0
	var landed := false
	var _r: Array = []
	var _i := 2
	var _seed := 0

	func _ready() -> void:
		z_index = 19 if kind == DUST else 20
		var tn := PX.tone(color)
		_r = tn[0]
		_i = tn[1]
		_seed = randi() % 7
		if delay > 0.0:
			visible = false

	func _c(step: int) -> Color:
		return _r[clampi(_i + step, 0, _r.size() - 1)]

	func _process(dt: float) -> void:
		if delay > 0.0:
			delay -= dt
			if delay > 0.0:
				return
			visible = true
		t += dt
		if t >= life:
			queue_free()
			return
		if not landed:
			if drag > 0.0:
				vel *= maxf(0.0, 1.0 - drag * dt)
			vel.y += grav * dt
			position += vel * dt
			if position.y > floor_y and vel.y > 0.0 and grav > 0.0:
				position.y = floor_y
				if kind == GOO or (kind == CHUNK and vel.y < 50.0):
					landed = true
					vel = Vector2.ZERO
				else:
					vel.y *= -0.45 if kind == CHUNK else -0.3
					vel.x *= 0.6
		queue_redraw()

	func _draw() -> void:
		var k := t / life
		var fade := 1.0 if k < 0.7 else (0.7 if k < 0.85 else 0.4)
		if kind == SPARK:
			var c: Color = _c(4) if k < 0.15 else (_r[maxi(_i, 3)] if k < 0.4 else (_c(0) if k < 0.7 else _c(-1)))
			var sp := vel.length()
			var ln := minf(sp * stretch, maxlen) * (1.0 - 0.4 * k)
			if ln < PX.U or sp < 0.01:
				PX.dot(self, Vector2.ZERO, Color(c, fade), size)
				return
			PX.line(self, Vector2.ZERO, -vel / sp * ln, Color(c, fade), size)
			if k < 0.4:
				PX.dot(self, Vector2.ZERO, _c(4), size)
		elif kind == DOT or kind == EMBER:
			if kind == EMBER and k > 0.45 and (int(t * 24.0) + _seed) % 3 == 0:
				return  # titila
			var c: Color = _c(1) if k < 0.3 else (_c(0) if k < 0.7 else _c(-1))
			var s := size if k < 0.6 else maxf(PX.U, size - PX.U)
			PX.dot(self, Vector2.ZERO, Color(c, fade), s)
		elif kind == DUST:
			var e := 1.0 - pow(1.0 - minf(1.0, k * 1.5), 2.0)  # crece rápido y después frena
			var r := size * (0.45 + 0.85 * e)
			var base := mini(4, _i + 1) if k < 0.2 else (_i if k < 0.55 else maxi(0, _i - 1))
			if k < 0.5:  # bollito con sombra abajo
				PX.disc(self, Vector2(0, PX.U), r, _r[maxi(0, base - 1)])
				PX.disc(self, Vector2.ZERO, r, _r[base])
			elif k < 0.78:  # se deshace en damero
				PX.disc_dither(self, Vector2.ZERO, r, _r[base])
			else:
				PX.disc_dither(self, Vector2(0, -PX.U), r * 0.9, _r[base], true)
		elif kind == CHUNK:
			if k > 0.72 and int(t * 20.0) % 2 == 0:
				return  # parpadea antes de irse
			var o := Vector2(-PX.snap(size / 2.0), -PX.snap(size / 2.0))
			draw_rect(Rect2(o, Vector2(size, size)), _r[_i])
			if size > PX.U:
				draw_rect(Rect2(o, Vector2(PX.U, PX.U)), _c(1))
				draw_rect(Rect2(o + Vector2(size - PX.U, size - PX.U), Vector2(PX.U, PX.U)), _c(-2))
		elif kind == GOO:
			if landed:
				var w := PX.snap(maxf(PX.U, size * 2.0 * (1.0 - k * 0.6)))
				draw_rect(Rect2(-PX.snap(w / 2.0), -PX.U, w, PX.U), Color(_r[_i], fade))
				if w > 1.0:
					draw_rect(Rect2(-PX.snap(w / 2.0), -PX.U, PX.U, PX.U), Color(_c(2), fade))
				return
			if vel.length() > 30.0:
				PX.line(self, Vector2.ZERO, -vel.normalized() * 1.5, _c(-1))
			PX.disc(self, Vector2.ZERO, size * 0.75, _r[_i])
			PX.dot(self, Vector2(-PX.U, -PX.U), _c(2))


## Anillo de píxeles: arranca como un disco blanco, se abre frenando y se afina y oscurece.
class Ring extends Node2D:
	const PX := preload("res://scripts/pix.gd")
	var color := Color.WHITE
	var t := 0.0
	var life := 0.4
	var rmax := 24.0
	var flat := 1.0
	var _r: Array = []
	var _i := 2

	func _ready() -> void:
		z_index = 20
		var tn := PX.tone(color)
		_r = tn[0]
		_i = tn[1]

	func _process(dt: float) -> void:
		t += dt
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < 0.0:
			return
		var k := clampf(t / life, 0.0, 1.0)
		var r := 2.0 + (rmax - 2.0) * (1.0 - pow(1.0 - k, 2.2))
		var th := 2.0 if k < 0.2 else (1.5 if k < 0.45 else (1.0 if k < 0.7 else 0.5))
		var c: Color = _r[4] if k < 0.15 else (_r[_i] if k < 0.55 else _r[maxi(0, _i - 1)])
		if k > 0.7:
			c.a = 0.5
			if k > 0.85 and int(t * 30.0) % 2 == 0:
				return  # se deshace titilando
		PX.ring(self, Vector2.ZERO, r, c, th, r * flat)


## Estrella de golpe (rayos en la dirección del impacto) o destello de cuatro puntas (twinkle).
class Star extends Node2D:
	const PX := preload("res://scripts/pix.gd")
	const DIAG := [Vector2(0.707, 0.707), Vector2(-0.707, 0.707), Vector2(0.707, -0.707), Vector2(-0.707, -0.707)]
	var dir := Vector2.RIGHT
	var color := Color.WHITE
	var big := false
	var twinkle := false
	var size := 5.5
	var life := 0.16
	var t := 0.0
	var _r: Array = []
	var _i := 2

	func _ready() -> void:
		z_index = 22
		var tn := PX.tone(color)
		_r = tn[0]
		_i = tn[1]

	func _process(dt: float) -> void:
		t += dt
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := t / life
		var white: Color = Pal.RAMP_W[3]
		if twinkle:
			var ln := size * sin(PI * minf(1.0, k * 1.1))
			var c: Color = _r[4] if k < 0.5 else _r[maxi(_i, 3)]
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				PX.ray(self, Vector2.ZERO, d, ln, c, 1.0 if ln > 2.5 else PX.U)
			for d in DIAG:
				PX.ray(self, Vector2.ZERO, d, ln * 0.35, _r[_i], PX.U)
			PX.dot(self, Vector2.ZERO, white, 1.0 if ln > 1.5 else PX.U)
			return
		var n := dir
		var p := dir.orthogonal()
		var ln := size
		if k < 0.25:
			PX.disc(self, Vector2.ZERO, 2.5 if big else 1.5, white)
			PX.ray(self, Vector2.ZERO, n, ln, white, 1.5)
			PX.ray(self, Vector2.ZERO, -n, ln * 0.55, white, 1.0)
			PX.ray(self, Vector2.ZERO, p, ln * 0.6, white, 1.0)
			PX.ray(self, Vector2.ZERO, -p, ln * 0.6, white, 1.0)
		elif k < 0.5:
			var c: Color = _r[4]
			PX.ray(self, n, n, ln * 1.2, c, 1.0)
			PX.ray(self, -n, -n, ln * 0.65, c, PX.U)
			PX.ray(self, p, p, ln * 0.7, c, PX.U)
			PX.ray(self, -p, -p, ln * 0.7, c, PX.U)
			PX.ring(self, Vector2.ZERO, 2.0 if big else 1.5, _r[maxi(_i, 3)], PX.U)
			if big:
				for d in DIAG:
					PX.ray(self, d * 2.0, d, ln * 0.45, _r[_i], PX.U)
		elif k < 0.75:
			var c2: Color = _r[_i]
			PX.line(self, n * ln * 0.6, n * ln * 1.3, c2)
			PX.line(self, -n * ln * 0.35, -n * ln * 0.75, c2)
			PX.line(self, p * ln * 0.4, p * ln * 0.8, c2)
			PX.line(self, -p * ln * 0.4, -p * ln * 0.8, c2)
		else:
			var c3: Color = _r[maxi(0, _i - 1)]
			for q in [n * ln * 1.35, -n * ln * 0.8, p * ln * 0.85, -p * ln * 0.85]:
				PX.dot(self, q, c3)


## Media luna de un tajo: filo blanco afuera, el color en el medio y el tono oscuro adentro. La cola se
## va comiendo hacia la punta mientras se afina.
class Smear extends Node2D:
	const PX := preload("res://scripts/pix.gd")
	var r := 30.0
	var a0 := -150.0
	var a1 := 40.0
	var face := 1.0
	var width := 6.0
	var color := Color.WHITE
	var life := 0.16
	var t := 0.0
	var _r: Array = []
	var _i := 2

	func _ready() -> void:
		z_index = 21
		var tn := PX.tone(color)
		_r = tn[0]
		_i = tn[1]

	func _process(dt: float) -> void:
		t += dt
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / life, 0.0, 1.0)
		var head := 1.0 - pow(1.0 - minf(1.0, t / (life * 0.5)), 2.0)  # sigue a la espada
		var tail := clampf(k * 1.2 - 0.2, 0.0, head - 0.08)
		if head - tail < 0.08:
			return
		var wk := 1.0 - 0.55 * k
		var a := 1.0 if k < 0.7 else 0.55
		_band(tail, head, 1.0, wk, Color(_r[maxi(0, _i - 1)], a))
		_band(tail, head, 0.7, wk, Color(_r[_i], a))
		_band(tail, head, 0.28, wk, Color(_r[4], a))

	func _band(tail: float, head: float, frac: float, wk: float, c: Color) -> void:
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var n := 20
		for j in n + 1:
			var s := lerpf(tail, head, float(j) / float(n))
			var ang := deg_to_rad(lerpf(a0, a1, s))
			var d := Vector2(cos(ang) * face, sin(ang))
			var ss := (s - tail) / maxf(0.001, head - tail)
			var w := maxf(PX.U, width * wk * frac * pow(ss, 0.8))
			outer.append(d * r)
			inner.append(d * (r - w))
		inner.reverse()
		outer.append_array(inner)
		draw_colored_polygon(outer, c)


## Bola de fuego de pixel art: un racimo de bollos que pasa de blanco a amarillo, naranja y rojo
## oscuro, se infla, sube un poco y se ahueca; el humo y las brasas los larga Fx.boom.
class Boom extends Node2D:
	const PX := preload("res://scripts/pix.gd")
	var r := 7.0
	var t := 0.0
	var lobes: Array = []  # [desplazamiento, tamaño]

	func _ready() -> void:
		z_index = 21
		lobes.append([Vector2.ZERO, 1.0])
		var a0 := randf() * TAU
		for i in 4:
			var a := a0 + i * TAU / 4.0 + randf_range(-0.4, 0.4)
			lobes.append([Vector2(cos(a), sin(a) * 0.8) * r * randf_range(0.45, 0.65), randf_range(0.5, 0.7)])

	func _process(dt: float) -> void:
		t += dt
		if t >= 0.34:
			queue_free()
		queue_redraw()

	func _layer(grow: float, col: Color, k: float, rise: float) -> void:
		for l in lobes:
			var o: Vector2 = l[0]
			PX.disc(self, o * grow + Vector2(0, -rise), r * float(l[1]) * k, col)

	func _draw() -> void:
		var rise := t * 14.0
		if t < 0.04:
			_layer(0.7, Pal.RAMP_W[3], 0.8, 0.0)
		elif t < 0.1:
			_layer(1.0, Pal.RAMP_O[2], 1.0, rise)
			_layer(0.9, Pal.RAMP_Y[2], 0.72, rise)
			_layer(0.6, Pal.RAMP_Y[4], 0.35, rise)
		elif t < 0.17:
			_layer(1.15, Pal.RAMP_R[2], 1.05, rise)
			_layer(1.1, Pal.RAMP_O[2], 0.8, rise)
			_layer(0.8, Pal.RAMP_Y[2], 0.4, rise)
		elif t < 0.25:
			_layer(1.25, Pal.RAMP_R[1], 1.0, rise)
			_layer(1.2, Pal.RAMP_O[1], 0.6, rise)
		else:
			for l in lobes:
				var o: Vector2 = l[0]
				PX.ring(self, o * 1.3 + Vector2(0, -rise), r * float(l[1]) * 0.9, Color(Pal.RAMP_R[0], 0.7), PX.U)


## Charco de slime en el piso: elipse con brillo y gotitas alrededor, que se seca de afuera.
class Splat extends Node2D:
	const PX := preload("res://scripts/pix.gd")
	var color := Color.WHITE
	var w := 9.0
	var t := 0.0
	var life := 1.6
	var drops: Array = []
	var _r: Array = []
	var _i := 2

	func _ready() -> void:
		z_index = -2
		var tn := PX.tone(color)
		_r = tn[0]
		_i = tn[1]
		for i in 4:
			drops.append(Vector2(PX.snap(randf_range(-w, w) * 0.85), -PX.U * float(randi() % 2)))

	func _process(dt: float) -> void:
		t += dt
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := t / life
		if k > 0.8 and int(t * 20.0) % 2 == 0:
			return
		var spread := minf(1.0, t / 0.08)  # se desparrama de golpe
		var ww := w * spread * (1.0 if k < 0.55 else 1.0 - (k - 0.55) * 1.6)
		if ww < 1.0:
			return
		PX.disc(self, Vector2(0, -PX.U), ww / 2.0, _r[maxi(0, _i - 1)], 1.0)
		PX.disc(self, Vector2(0, -1.0), ww / 2.0 - PX.U, _r[_i], 0.75)
		draw_rect(Rect2(PX.snap(-ww * 0.25), -1.5, PX.snap(maxf(PX.U, ww * 0.2)), PX.U), _r[mini(4, _i + 2)])
		if k < 0.6:
			for d in drops:
				PX.dot(self, d, _r[_i], 1.0)


class Warmer:
	extends Node2D
	## Dibuja casi invisible unos cuadros con cada modo (rectángulo, textura, polígono, línea) y se va.
	var frames := 0
	var tex: ImageTexture

	func _ready() -> void:
		z_index = 60
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0.0))
		tex = ImageTexture.create_from_image(img)

	func _process(_dt: float) -> void:
		frames += 1
		queue_redraw()
		if frames > 4:
			queue_free()

	func _draw() -> void:
		var c := Color(0, 0, 0, 0.002)
		draw_rect(Rect2(0, 0, 1, 1), c)
		draw_texture(tex, Vector2.ZERO)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]), c)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]),
				PackedColorArray([c, c, c]))
		draw_line(Vector2.ZERO, Vector2(1, 1), c)
		draw_line(Vector2.ZERO, Vector2(1, 1), c, 1.0)
		draw_circle(Vector2.ZERO, 1.0, c)
