extends RefCounted
## Dibujo a medio píxel (el píxel de los sprites HD) para los efectos: puntos, líneas, discos y anillos
## sin suavizado, y las rampas de color de Pal para que una chispa nazca blanca y se enfríe hacia el
## tono oscuro de su color, como en el pixel art a mano.

const U := 0.5  # medio píxel lógico = un píxel de pantalla

static var _ramps := {}


static func snap(v: float) -> float:
	return roundf(v * 2.0) / 2.0


static func snapv(v: Vector2) -> Vector2:
	return Vector2(snap(v.x), snap(v.y))


## [rampa de 5 tonos, índice del color en la rampa]. Si el color no es de la paleta arma una rampa.
static func tone(c: Color) -> Array:
	if _ramps.is_empty():
		for r in [Pal.RAMP_K, Pal.RAMP_D, Pal.RAMP_SS, Pal.RAMP_S, Pal.RAMP_W, Pal.RAMP_N, Pal.RAMP_BB,
				Pal.RAMP_B, Pal.RAMP_C, Pal.RAMP_GG, Pal.RAMP_G, Pal.RAMP_L, Pal.RAMP_Y, Pal.RAMP_O,
				Pal.RAMP_R, Pal.RAMP_P]:
			for i in r.size():
				var k: String = (r[i] as Color).to_html(false)
				if i == 2 or not _ramps.has(k):
					_ramps[k] = [r, i]
	var key := c.to_html(false)
	if _ramps.has(key):
		return _ramps[key]
	var made := [[c.darkened(0.55), c.darkened(0.3), c, c.lightened(0.35), c.lightened(0.7)], 2]
	_ramps[key] = made
	return made


## Un tono de la rampa del color: 0 el más oscuro, 4 el más claro (se corta en los bordes).
static func shade(c: Color, step: int) -> Color:
	var tn := tone(c)
	var r: Array = tn[0]
	return r[clampi(int(tn[1]) + step, 0, r.size() - 1)]


## Cuadradito de lado s centrado (a la grilla de medio píxel).
static func dot(ci: CanvasItem, p: Vector2, col: Color, s: float = U) -> void:
	var o := floorf(s / U / 2.0) * U
	ci.draw_rect(Rect2(snap(p.x) - o, snap(p.y) - o, s, s), col)


## Línea de píxeles de grosor w (sin suavizado).
static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float = U) -> void:
	var d := b - a
	var n := int(ceilf(maxf(absf(d.x), absf(d.y)) / U))
	if n <= 0:
		dot(ci, a, col, w)
		return
	var last := Vector2(INF, INF)
	for i in n + 1:
		var p := snapv(a + d * (float(i) / float(n)))
		if p != last:
			dot(ci, p, col, w)
			last = p


## Rayo que se afina: grueso w en la base, de medio píxel en la punta.
static func ray(ci: CanvasItem, from: Vector2, dir: Vector2, length: float, col: Color, w: float = 1.0) -> void:
	if length <= 0.0:
		return
	var tip := from + dir * length
	if w > U:
		line(ci, from, from + dir * length * 0.45, col, w)
	line(ci, from, tip, col, U)


## Disco relleno (una fila de medio píxel por vez). ry < rx lo aplasta.
static func disc(ci: CanvasItem, c: Vector2, rx: float, col: Color, ry: float = -1.0) -> void:
	if ry < 0.0:
		ry = rx
	if rx < U * 0.5 or ry < U * 0.5:
		return
	c = snapv(c)
	var top := snap(ry)
	var y := -top
	while y < top:
		var yy := y + U / 2.0
		var hw := snap(rx * sqrt(maxf(0.0, 1.0 - (yy * yy) / (ry * ry))))
		if hw > 0.0:
			ci.draw_rect(Rect2(c.x - hw, c.y + y, hw * 2.0, U), col)
		y += U
	if top <= 0.0:
		dot(ci, c, col)


## Anillo de píxeles de grosor th. ry < rx lo aplasta (onda en el piso).
static func ring(ci: CanvasItem, c: Vector2, rx: float, col: Color, th: float = U, ry: float = -1.0) -> void:
	if ry < 0.0:
		ry = rx
	if rx < U or ry < U:
		dot(ci, c, col)
		return
	c = snapv(c)
	var irx := rx - th
	var iry := ry - th * (ry / rx)
	var top := snap(ry)
	var y := -top
	while y < top:
		var yy := y + U / 2.0
		var o := snap(rx * sqrt(maxf(0.0, 1.0 - (yy * yy) / (ry * ry))))
		if o > 0.0:
			var i := 0.0
			if iry > 0.0 and absf(yy) < iry:
				i = snap(irx * sqrt(maxf(0.0, 1.0 - (yy * yy) / (iry * iry))))
			if i <= 0.0:
				ci.draw_rect(Rect2(c.x - o, c.y + y, o * 2.0, U), col)
			else:
				var w := maxf(U, o - i)
				ci.draw_rect(Rect2(c.x - o, c.y + y, w, U), col)
				ci.draw_rect(Rect2(c.x + o - w, c.y + y, w, U), col)
		y += U


## Disco tramado (damero): el humo y el polvo se deshacen así, como en el pixel art a mano.
## sparse true deja una de cada cuatro.
static func disc_dither(ci: CanvasItem, c: Vector2, r: float, col: Color, sparse: bool = false) -> void:
	if r < U:
		return
	c = snapv(c)
	var top := snap(r)
	var y := -top
	var row := 0
	while y < top:
		var yy := y + U / 2.0
		var hw := snap(r * sqrt(maxf(0.0, 1.0 - (yy * yy) / (r * r))))
		if hw > 0.0 and not (sparse and row % 2 == 1):
			var x := -hw
			if (int(roundf((c.x + x) * 2.0)) + row) % 2 != 0:
				x += U  # el damero sigue la grilla, no el borde de cada fila
			while x < hw:
				ci.draw_rect(Rect2(c.x + x, c.y + y, U, U), col)
				x += U * 2.0
		y += U
		row += 1
