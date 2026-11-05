extends Node2D
## Cielo con nubes y colinas que se mueven más lento que la cámara (parallax simple).

const W := 256
const H := 144


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var cx := 0.0
	if cam:
		cx = cam.get_screen_center_position().x - W / 2.0
	# cielo en franjas (dithering de 16 bits)
	var sky := [Color("5d9fd9"), Color("6dafe3"), Color("82c0ea"), Color("9ad0ef"), Color("b5def2")]
	for i in sky.size():
		draw_rect(Rect2(cx, i * 22, W, 22 if i < sky.size() - 1 else H), sky[i])
	# nubes (se mueven al 15%)
	for i in 6:
		var x := fposmod(i * 97.0 - cx * 0.15, W + 80.0) - 40.0 + cx
		var y := 14.0 + (i * 23) % 40
		draw_rect(Rect2(x, y, 34, 6), Color(1, 1, 1, 0.9))
		draw_rect(Rect2(x + 6, y - 4, 20, 5), Color(1, 1, 1, 0.9))
	# colinas lejanas (30%) y cercanas (55%)
	_hills(cx, 0.3, 96.0, 22.0, 70.0, Color("7fb89a"))
	_hills(cx, 0.55, 108.0, 16.0, 48.0, Color("5c9e6e"))


func _hills(cx: float, f: float, base: float, amp: float, period: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var off := cx * f
	for sx in range(0, W + 9, 4):
		var wx := sx + off
		var y := base - absf(sin(wx / period)) * amp - sin(wx / (period * 0.37)) * 3.0
		pts.append(Vector2(cx + sx, floorf(y)))
	pts.append(Vector2(cx + W + 8, H))
	pts.append(Vector2(cx, H))
	draw_colored_polygon(pts, col)
