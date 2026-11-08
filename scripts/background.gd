extends Node2D
## Fondo del Reino, pintado con PixelLab (tools/bg arma las capas): cielo de noche con luna (fijo),
## estrellas que titilan, nubes, la cordillera con el castillo del rey (parallax 0.25) y el bosque, las
## ruinas y las murallas según la zona (0.5).

const W := 256
# estrellas que titilan: x, y, velocidad, fase (TWINKLE del original)
const TWINKLE := [[191.5, 54, 1.897, 5.519], [110.5, 3, 1.795, 2.069], [139.5, 63.5, 3.092, 2.865], [72, 66, 1.845, 1.066], [36.5, 65.5, 2.397, 3.710], [164.5, 54.5, 2.454, 2.164], [98, 50.5, 3.298, 1.206], [32, 69.5, 2.480, 3.104], [232.5, 32.5, 1.525, 3.650], [198.5, 5.5, 1.959, 5.685], [88.5, 35, 2.159, 0.847], [241.5, 38.5, 2.051, 4.334], [15.5, 27, 3.149, 0.849], [223, 53.5, 3.126, 1.478], [132, 67, 3.111, 3.827], [7.5, 71, 3.465, 5.585]]
# nubes: x, y, velocidad
const CLOUDS := [[20, 18, 3], [120, 34, 2], [230, 12, 4]]

var main  # main.gd, para leer la cámara
var sky: Sprite2D
var far: Sprite2D
var mid: Sprite2D
var clouds: Array = []
var stars: Node2D
var t := 0.0


func _ready() -> void:
	z_index = -10
	sky = _layer(preload("res://assets/level1/sky.png"))
	stars = Stars.new()
	add_child(stars)
	var tex := [preload("res://assets/level1/cloud0.png"), preload("res://assets/level1/cloud1.png"), preload("res://assets/level1/cloud2.png")]
	for i in CLOUDS.size():
		clouds.append(_layer(tex[i]))
	far = _layer(preload("res://assets/level1/far.png"))
	mid = _layer(preload("res://assets/level1/mid.png"))


func _layer(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.scale = Vector2(0.5, 0.5)
	add_child(s)
	return s


func _process(dt: float) -> void:
	t += dt
	var cx: float = main.cam_x if main else 0.0
	var q := func(v: float) -> float: return roundf(v * 2.0) / 2.0
	sky.position = Vector2(cx, 0)
	stars.position = Vector2(cx, 0)
	stars.t = t
	for i in CLOUDS.size():
		var c: Array = CLOUDS[i]
		var x := fposmod(c[0] + t * c[2] - cx * 0.2, W + 60.0) - 40.0
		clouds[i].position = Vector2(cx + q.call(x) - 4, c[1] - 7)
	far.position = Vector2(cx - q.call(cx * 0.25), 0)
	mid.position = Vector2(cx - q.call(cx * 0.5), 0)


class Stars extends Node2D:
	var t := 0.0

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for s in TWINKLE:
			var v := sin(t * s[2] + s[3])
			if v < 0.2:
				continue
			draw_rect(Rect2(s[0], s[1], 0.5, 0.5), Color.WHITE if v > 0.8 else Pal.S)
			if v > 0.93:
				var c: Color = Pal.RAMP_S[3]
				draw_rect(Rect2(s[0] - 0.5, s[1], 0.5, 0.5), c)
				draw_rect(Rect2(s[0] + 0.5, s[1], 0.5, 0.5), c)
				draw_rect(Rect2(s[0], s[1] - 0.5, 0.5, 0.5), c)
				draw_rect(Rect2(s[0], s[1] + 0.5, 0.5, 0.5), c)
