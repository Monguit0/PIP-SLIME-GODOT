extends Node2D
## Moneda: gira, flota y aparece con un saltito. La junta Pip o una flecha que pasa.
## Cada una seguida sube el combo (y la nota, por la escala mayor).

const TEX := preload("res://assets/sprites/items/coin.png")

var t := 0.0
var glint := 0.0   # destellito cada tanto
var born := 0.0
var got := false
var game  # main.gd


func _ready() -> void:
	add_to_group("monedas")
	z_index = 2
	t = randf() * 6.0
	glint = randf_range(0.5, 2.5)


func can_take() -> bool:
	return not got and born >= 0.0


func take() -> void:
	if not can_take():
		return
	got = true
	if game != null:
		game.collect_coin(self)
	queue_free()


func _physics_process(dt: float) -> void:
	t += dt
	born += dt
	glint -= dt
	if glint < -0.2:
		glint = randf_range(1.6, 3.2)
	var p: Player = game.player if game != null else null
	if can_take() and p != null and not p.dead and p.box().intersects(Rect2(global_position.x - 3, global_position.y - 4, 6, 8)):
		take()
	queue_redraw()


func _draw() -> void:
	if born < 0.0:
		return
	var pop := minf(1.0, born / 0.25)
	var spin := absf(cos(t * 3.2))
	var bob := roundf(sin(t * 4.0) * 1.5)
	var w := maxf(2.0, roundf(6.0 * spin)) * ((0.5 + pop * 0.6) if pop < 1.0 else 1.0)
	w = roundf(w)
	draw_texture_rect(TEX, Rect2(-w / 2.0, -3.0 + bob, w, 7), false)
	# destellito de cuatro puntas en el borde
	if glint < 0.0 and pop >= 1.0:
		var k := sin(-glint / 0.2 * PI)
		var gp := Vector2(roundf(w * 0.25 * 2.0) / 2.0, -2.0 + bob)
		var arm := roundf(k * 2.0 * 2.0) / 2.0
		draw_rect(Rect2(gp.x - arm, gp.y, arm * 2.0 + 0.5, 0.5), Pal.RAMP_Y[4])
		draw_rect(Rect2(gp.x, gp.y - arm, 0.5, arm * 2.0 + 0.5), Pal.RAMP_Y[4])
