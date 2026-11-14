extends Node2D
## La nube de esporas que deja el hongo al morir: queda unos segundos y lastima al héroe que se queda adentro.

const LIFE := 3.0
const RAD := 22.0
const TICK := 0.7

var t := 0.0
var hit := {}   # héroe -> cuándo puede volver a lastimarlo


func _ready() -> void:
	z_index = 3
	add_to_group("esporas")
	Snd.play("explotar", {"rate": 0.6, "vol": 0.5})


func _physics_process(dt: float) -> void:
	t += dt
	queue_redraw()
	if t > LIFE:
		queue_free()
		return
	if Engine.get_physics_frames() % 3 == 0:
		var a := randf() * TAU
		var r := randf() * RAD
		Fx.part(get_parent(), global_position + Vector2(cos(a) * r, -8.0 + sin(a) * r * 0.6), Vector2(randf_range(-6, 6), -randf_range(6, 16)), -10.0, 0.6, Pal.L if randf() < 0.6 else Color("2a6149"))
	if t < 0.25:
		return
	var area := Rect2(global_position.x - RAD, global_position.y - RAD - 6.0, RAD * 2.0, RAD + 8.0)
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p == null or p.dead or not p.box().intersects(area):
			continue
		if float(hit.get(p, -9.0)) + TICK <= t:
			hit[p] = t
			p.hurt(global_position.x, 1, self)


func _draw() -> void:
	# nubecitas verdes que laten y se van apagando
	var fade := clampf((LIFE - t) / 0.6, 0.0, 1.0) * clampf(t / 0.2, 0.0, 1.0)
	for i in 7:
		var a := i * TAU / 7.0 + t * 0.6
		var r := RAD * (0.45 + 0.25 * sin(t * 2.0 + i))
		var c := Vector2(cos(a) * r, -9.0 + sin(a) * r * 0.5)
		draw_circle(c, 7.0 + sin(t * 3.0 + i * 2.0) * 1.5, Color(0.25, 0.8, 0.2, 0.2 * fade))
	draw_circle(Vector2(0, -9), RAD * 0.7, Color(0.3, 0.9, 0.3, 0.14 * fade))
