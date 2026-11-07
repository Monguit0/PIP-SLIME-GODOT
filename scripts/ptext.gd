class_name PText
## La fuente 5x7 del juego web, a medio píxel, con sombra y degradé en los títulos (tamaño 2 o más).
## Se dibuja con rectángulos sobre cualquier CanvasItem, en coordenadas de 256x144.

const ROWS := {
	"%": "11001 11010 00010 00100 01000 01011 10011", ",": "00000 00000 00000 00000 00110 00100 01000",
	"0": "01110 10001 10011 10101 11001 10001 01110", "1": "00100 01100 00100 00100 00100 00100 01110",
	"2": "01110 10001 00001 00010 00100 01000 11111", "3": "11111 00010 00100 00010 00001 10001 01110",
	"4": "00010 00110 01010 10010 11111 00010 00010", "5": "11111 10000 11110 00001 00001 10001 01110",
	"6": "00110 01000 10000 11110 10001 10001 01110", "7": "11111 00001 00010 00100 01000 01000 01000",
	"8": "01110 10001 10001 01110 10001 10001 01110", "9": "01110 10001 10001 01111 00001 00010 01100",
	"A": "01110 10001 10001 11111 10001 10001 10001", "B": "11110 10001 10001 11110 10001 10001 11110",
	"C": "01110 10001 10000 10000 10000 10001 01110", "D": "11100 10010 10001 10001 10001 10010 11100",
	"E": "11111 10000 10000 11110 10000 10000 11111", "F": "11111 10000 10000 11110 10000 10000 10000",
	"G": "01110 10001 10000 10111 10001 10001 01111", "H": "10001 10001 10001 11111 10001 10001 10001",
	"I": "01110 00100 00100 00100 00100 00100 01110", "J": "00111 00010 00010 00010 00010 10010 01100",
	"K": "10001 10010 10100 11000 10100 10010 10001", "L": "10000 10000 10000 10000 10000 10000 11111",
	"M": "10001 11011 10101 10101 10001 10001 10001", "N": "10001 10001 11001 10101 10011 10001 10001",
	"O": "01110 10001 10001 10001 10001 10001 01110", "P": "11110 10001 10001 11110 10000 10000 10000",
	"Q": "01110 10001 10001 10001 10101 10010 01101", "R": "11110 10001 10001 11110 10100 10010 10001",
	"S": "01111 10000 10000 01110 00001 00001 11110", "T": "11111 00100 00100 00100 00100 00100 00100",
	"U": "10001 10001 10001 10001 10001 10001 01110", "V": "10001 10001 10001 10001 10001 01010 00100",
	"W": "10001 10001 10001 10101 10101 10101 01010", "X": "10001 10001 01010 00100 01010 10001 10001",
	"Y": "10001 10001 01010 00100 00100 00100 00100", "Z": "11111 00001 00010 00100 01000 10000 11111",
	"!": "00100 00100 00100 00100 00100 00000 00100", "¡": "00100 00000 00100 00100 00100 00100 00100",
	"+": "00000 00100 00100 11111 00100 00100 00000", "x": "00000 00000 10001 01010 00100 01010 10001",
	":": "00000 01100 01100 00000 01100 01100 00000", ".": "00000 00000 00000 00000 00000 01100 01100",
	"-": "00000 00000 00000 11111 00000 00000 00000", "?": "01110 10001 00001 00010 00100 00000 00100",
	" ": "00000 00000 00000 00000 00000 00000 00000", ">": "01000 00100 00010 00001 00010 00100 01000",
	"<": "00010 00100 01000 10000 01000 00100 00010", "·": "00000 00000 00000 01100 01100 00000 00000",
	"/": "00001 00010 00010 00100 01000 01000 10000",
}
## los tamaños del original (1 a 4) en medios píxeles: 1 -> 1, 2 -> 3, 3 -> 4, 4 -> 6
const SCMAP := {1: 1, 2: 3, 3: 4, 4: 6}
const ACCENTS := {"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ñ": "N", "Ü": "U",
	"á": "A", "é": "E", "í": "I", "ó": "O", "ú": "U", "ñ": "N", "ü": "U"}

static var _glyphs := {}


static func _glyph(ch: String) -> Array:
	if _glyphs.is_empty():
		for k in ROWS:
			var bits: String = ROWS[k].replace(" ", "")
			var px := []
			for j in 35:
				if bits[j] == "1":
					px.append(Vector2i(j % 5, j / 5))
			_glyphs[k] = px
	return _glyphs.get(ch, _glyphs["?"])


static func norm(s: String) -> String:
	var out := ""
	for ch in s:
		var c: String = ACCENTS.get(ch, ch)
		if not ROWS.has(c) and ROWS.has(c.to_upper()):
			c = c.to_upper()
		out += c
	return out


static func unit(sc: int) -> float:
	return float(SCMAP.get(sc, maxi(1, roundi(sc * 1.5)))) / 2.0


static func width(s: String, sc: int = 1) -> float:
	var u := unit(sc)
	return norm(s).length() * 6 * u - u


## align: 0 izquierda, 1 centro, 2 derecha. shadow = Color(0,0,0,0) para no tener sombra.
static func draw(ci: CanvasItem, s: String, x: float, y: float, color: Color, sc: int = 1, align: int = 0,
		shadow: Color = Color(0, 0, 0, 1), ramp: Array = []) -> void:
	s = norm(s)
	var u := unit(sc)
	var tw := width(s, sc)
	if align == 1:
		x -= tw / 2.0
	elif align == 2:
		x -= tw
	x = roundf(x * 2.0) / 2.0
	y = roundf(y * 2.0) / 2.0
	if shadow.a > 0.0:
		var sh := Color(shadow, shadow.a * color.a)
		if sc >= 2:
			_pass(ci, s, x + u, y + u, u, sh, [])
			for o in [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0, -0.5), Vector2(0, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
				_pass(ci, s, x + o.x, y + o.y, u, sh, [])
		else:
			_pass(ci, s, x + 0.5, y, u, sh, [])
			_pass(ci, s, x, y + 0.5, u, sh, [])
			_pass(ci, s, x + 0.5, y + 0.5, u, sh, [])
	_pass(ci, s, x, y, u, color, ramp if sc >= 2 else [])


static func _pass(ci: CanvasItem, s: String, x: float, y: float, u: float, col: Color, ramp: Array) -> void:
	var i := 0
	for ch in s:
		for g in _glyph(ch):
			var c := col
			if ramp.size() >= 4:
				c = ramp[3] if g.y < 2 else (ramp[1] if g.y > 4 else ramp[2])
				c.a = col.a
			ci.draw_rect(Rect2(x + (i * 6 + g.x) * u, y + g.y * u, u, u), c)
		i += 1
