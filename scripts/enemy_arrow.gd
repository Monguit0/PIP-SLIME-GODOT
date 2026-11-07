extends Node2D
## Flecha del esqueleto arquero (mobShoot del original): 205 px/s casi recta, lastima a Pip
## y se clava en el piso. Se puede esquivar saltando o con el dash.

const GROUND := 128.0

var face := 1.0
var game  # main.gd
var vel := Vector2.ZERO
var life := 0.0
var stuck := false


func _ready() -> void:
	z_index = 3
	vel = Vector2(face * 205.0, -10.0)


func _physics_process(dt: float) -> void:
	life += dt
	if stuck:
		modulate.a = clampf((1.0 - life) / 0.3, 0.0, 1.0)
		if life > 1.0:
			queue_free()
		return
	vel.y += 60.0 * dt
	position += vel * dt
	rotation = vel.angle()
	if randf() < 0.5:
		Fx.part(get_parent(), global_position - Vector2(face * 4.0, 0), Vector2.ZERO, 0.0, 0.12, Pal.L)
	if life > 1.8:
		queue_free()
		return
	var p: Player = game.player if game != null else null
	if p != null and not p.dead and p.box().has_point(global_position + Vector2(face * 2.0, 0)):
		if p.hurt(global_position.x - face * 10.0):
			Fx.burst(get_parent(), global_position, 5, [Pal.W, Pal.L], 50.0, 20.0, 0.3)
			queue_free()
			return
	if global_position.y >= GROUND - 1.0:
		global_position.y = GROUND - 1.0
		stuck = true
		life = 0.5
		Snd.play("clavar", {"vol": 0.4})
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2(-5, 0), Vector2(3, 0), Color("6b5a3a"), 1.0)
	draw_rect(Rect2(3, -1, 2, 2), Pal.L)  # punta con brillo verde, como los ojos del esqueleto
	draw_rect(Rect2(-6, -1, 2, 2), Pal.SS)
