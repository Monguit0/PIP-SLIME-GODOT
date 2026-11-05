extends CanvasLayer
## Corazones, barra de energía, slimes que quedan y carteles de victoria/derrota.

var player: Player
var main  # main.gd (sin tipo: se lee slimes_left y won)
var canvas: Control


func _ready() -> void:
	layer = 10
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)


func _process(_dt: float) -> void:
	canvas.queue_redraw()


func _draw_hud() -> void:
	if player == null:
		return
	var font := ThemeDB.fallback_font
	# corazones
	for i in player.max_hearts:
		_heart(Vector2(6 + i * 11, 6), i < player.hearts)
	# energía
	var bar := Rect2(6, 17, 40, 3)
	canvas.draw_rect(bar.grow(1), Color("1c1c28"))
	var col := Color("ff6060") if player.energy_flash > 0.0 and int(player.energy_flash * 20) % 2 == 0 else Color("7fd6ff")
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * player.energy / Player.EN_MAX, bar.size.y)), col)
	# carga del arco
	if player.charge >= Player.CHG_ON:
		var k := clampf(player.charge / Player.CHG_FULL, 0.0, 1.0)
		canvas.draw_rect(Rect2(6, 22, 40 * k, 1), Color.WHITE if k >= 1.0 else Color("c8d0d8"))
	# slimes
	canvas.draw_string(font, Vector2(200, 12), "SLIMES %d" % main.slimes_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	# carteles
	if main.won:
		_banner("¡ZONA LIMPIA!", "R o salto para jugar de nuevo")
	elif player.dead:
		_banner("PIP CAYÓ", "R o salto para reintentar")


func _banner(title: String, sub: String) -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_rect(Rect2(0, 52, 256, 36), Color(0, 0, 0, 0.6))
	canvas.draw_string(font, Vector2(0, 70), title, HORIZONTAL_ALIGNMENT_CENTER, 256, 16, Color("ffd84a"))
	canvas.draw_string(font, Vector2(0, 82), sub, HORIZONTAL_ALIGNMENT_CENTER, 256, 8, Color.WHITE)


func _heart(p: Vector2, full: bool) -> void:
	var rows := [".xx.xx.", "xxxxxxx", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."]
	var fill := Color("e8413c") if full else Color("3a2a34")
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "x":
				canvas.draw_rect(Rect2(p.x + x, p.y + y, 1, 1), fill)
	if full:
		canvas.draw_rect(Rect2(p.x + 1, p.y + 1, 1, 1), Color("ffb0a8"))
