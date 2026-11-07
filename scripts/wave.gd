extends Node2D
## Onda de choque del Mega Caballero cuando cae de un salto: corre por el piso y hay que saltarla.

const GROUND := 128.0

var game  # main.gd
var dir := 1
var spd := 150.0
var min_x := 0.0
var max_x := 9999.0


func _ready() -> void:
	z_index = 4


func _physics_process(dt: float) -> void:
	position.x += dir * spd * dt
	position.y = 0.0
	if randf() < 0.5:
		Fx.part(get_parent(), Vector2(position.x, GROUND - 2), Vector2(-dir * 20.0, -30.0), 200.0, 0.3, Pal.S if randf() < 0.5 else Pal.C)
	if position.x < min_x - 4.0 or position.x > max_x + 4.0:
		queue_free()
		return
	var p: Player = game.player if game != null else null
	if p != null and not p.dead and p.box().intersects(Rect2(position.x - 4, GROUND - 7, 8, 7)) and p.hurt(position.x - dir * 10.0):
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-4, GROUND - 2, 8, 2), Pal.C)
	draw_rect(Rect2(-3, GROUND - 4, 6, 2), Pal.W)
	draw_rect(Rect2(-1 + dir, GROUND - 7, 2, 3), Pal.W)
