extends CanvasLayer
## Corazones, barra de energía, carga del arco y carteles (ZONA 1 · PRADERA, ¡PASO LIBRE!...).
## Dibuja en coordenadas de 256x144 y se escala x2, como el resto del juego.

var player: Player
var main  # main.gd (sin tipo: se leen banner, won y over_t)
var canvas: Control


func _ready() -> void:
	layer = 10
	scale = Vector2(2, 2)
	canvas = Control.new()
	canvas.size = Vector2(256, 144)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)


func _process(_dt: float) -> void:
	canvas.queue_redraw()


func _draw_hud() -> void:
	if player == null:
		return
	for i in player.max_hearts:
		_heart(Vector2(6 + i * 9, 6), i < player.hearts)
	# energía
	var bar := Rect2(6, 15, 30, 2)
	canvas.draw_rect(bar.grow(1), Pal.K)
	var col := Pal.R if player.energy_flash > 0.0 and int(player.energy_flash * 20) % 2 == 0 else Pal.C
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * player.energy / Player.EN_MAX, bar.size.y)), col)
	# carga del arco
	if player.charge >= Player.CHG_ON:
		var k := clampf(player.charge / Player.CHG_FULL, 0.0, 1.0)
		canvas.draw_rect(Rect2(6, 19, 30 * k, 1), Pal.Y if k >= 1.0 else Pal.S)
	# carteles
	var b: Dictionary = main.banner
	if b.t < 2.2 and b.text != "":
		var a := clampf(minf(b.t / 0.15, (2.2 - b.t) / 0.4), 0.0, 1.0)
		_text(b.text, 52, 12, Color(Pal.Y, a))
		if b.sub != "":
			_text(b.sub, 62, 6, Color(Pal.W, a))
	if player.dead:
		canvas.draw_rect(Rect2(0, 52, 256, 36), Color(0, 0, 0, 0.6))
		_text("PIP CAYÓ", 70, 12, Pal.R)
		_text("R o salto para reintentar", 82, 6, Pal.W)
	elif main.won and main.over_t > 2.2:
		_text("R o salto para jugar de nuevo", 82, 6, Pal.W)


func _text(s: String, y: float, size: int, c: Color) -> void:
	var font := ThemeDB.fallback_font
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		canvas.draw_string(font, Vector2(0, y) + o * 0.5, s, HORIZONTAL_ALIGNMENT_CENTER, 256, size, Color(Pal.K, c.a))
	canvas.draw_string(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, 256, size, c)


func _heart(p: Vector2, full: bool) -> void:
	var rows := [".xx.xx.", "xxxxxxx", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "x":
				canvas.draw_rect(Rect2(p.x + x, p.y + y, 1, 1), Pal.R if full else Pal.D)
	if full:
		canvas.draw_rect(Rect2(p.x + 1, p.y + 1, 1, 1), Pal.RAMP_R[4])
