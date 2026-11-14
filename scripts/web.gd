extends Node2D
## La telaraña que escupe la araña: una bola de seda que vuela casi recta. Al pegarle a un héroe le saca 1 y
## lo deja envuelto: muy lento durante SLOW_T segundos. El escudo la frena (y entonces no enreda).

const SLOW_T := 2.5
const SLOW_K := 0.4   # a cuánto queda la velocidad del héroe enredado

var game
var src
var vel := Vector2.ZERO
var t := 0.0
# para el bot, que la mira como a una flecha
var face := 1.0
var stuck := false
var hero := false


func _ready() -> void:
	z_index = 4
	add_to_group("telas")
	face = signf(vel.x) if vel.x != 0.0 else 1.0


func _physics_process(dt: float) -> void:
	t += dt
	vel.y += 60.0 * dt
	position += vel * dt
	queue_redraw()
	if Engine.get_physics_frames() % 2 == 0:
		Fx.part(get_parent(), global_position, Vector2(randf_range(-6, 6), randf_range(-6, 6)), 0.0, 0.22, Pal.W if randf() < 0.6 else Pal.S)
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p != null and not p.dead and p.box().grow(2.0).has_point(global_position):
			if p.hurt(global_position.x - face * 8.0, 1, self):
				p.apply_slow(SLOW_T, SLOW_K)
			_splat()
			return
	if global_position.y >= 127.0 or t > 2.2 or (game != null and (global_position.x < game.cam_x - 30.0 or global_position.x > game.cam_x + 560.0)):
		_splat()


func _splat() -> void:
	Fx.burst(get_parent(), global_position, 8, [Pal.W, Pal.S], 70.0, 20.0, 0.35, 120.0)
	Fx.ring(get_parent(), global_position, Pal.W, 0.0, 8.0, 1.0, 0.2)
	Snd.play("baba", {"rate": 1.5, "vol": 0.5})
	queue_free()


func _draw() -> void:
	# bola de seda con hilos que giran
	var r := 2.5 + sin(t * 30.0) * 0.4
	draw_circle(Vector2.ZERO, r + 1.0, Pal.K)
	draw_circle(Vector2.ZERO, r, Pal.W)
	for i in 4:
		var a := t * 9.0 + i * TAU / 4.0
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * (r + 2.5), Pal.S, 0.5)
	draw_line(Vector2.ZERO, -vel.normalized() * 7.0, Color(Pal.W, 0.6), 0.5)
