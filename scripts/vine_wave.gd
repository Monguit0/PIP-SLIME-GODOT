extends Node2D
## Las enredaderas de la planta carnívora: brotan del piso y avanzan en onda. Lastiman una vez a cada héroe
## que agarran (pueden ser varios) y se saltan. Recorren REACH píxeles y se hunden.

const REACH := 120.0
const SPEED := 115.0
const LEN := 34.0     # largo del tramo de enredaderas que está afuera
const HIGH := 11.0

var dir := 1.0
var floor_y := 128.0
var gone := 0.0
var t := 0.0
var hit: Array = []
var src


func _ready() -> void:
	z_index = 3
	Snd.play("tajo", {"rate": 0.5, "vol": 0.6})


func _physics_process(dt: float) -> void:
	t += dt
	gone += SPEED * dt
	queue_redraw()
	if gone > REACH + LEN:
		queue_free()
		return
	var head := minf(gone, REACH)
	var tail := maxf(0.0, gone - LEN)
	if tail >= head:
		return
	if Engine.get_physics_frames() % 3 == 0:
		Fx.dust(get_parent(), global_position + Vector2(dir * head, 0), 1, 14.0, 4.0, 1.4, Color("5a3a25"))
	var x0 := global_position.x + dir * tail
	var x1 := global_position.x + dir * head
	var area := Rect2(minf(x0, x1), floor_y - HIGH, absf(x1 - x0), HIGH)
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p != null and not p.dead and not hit.has(p) and p.box().intersects(area):
			hit.append(p)
			p.hurt(global_position.x + dir * (tail - 4.0), 1, self)


func _draw() -> void:
	var head := minf(gone, REACH)
	var tail := maxf(0.0, gone - LEN)
	# tallos espinosos que suben y bajan como una ola: más altos en el medio del tramo
	var x := tail
	while x < head:
		var k := (x - tail) / maxf(1.0, head - tail)
		var up := sin(k * PI) * HIGH * (0.75 + 0.25 * sin(x * 0.5 + t * 14.0))
		var px := dir * x + sin(x * 0.7 + t * 10.0) * 1.2
		var base := Vector2(px, floor_y - global_position.y)
		draw_line(base, base + Vector2(0, -up), Pal.K, 2.5)
		draw_line(base, base + Vector2(0, -up), Color("189030"), 1.5)
		draw_rect(Rect2(base.x - 0.5, base.y - up - 1.0, 1, 1), Color("41ce11"))
		if int(x) % 8 < 4 and up > 4.0:
			draw_rect(Rect2(base.x + dir * 1.0, base.y - up * 0.5, 1, 1), Pal.W)
		x += 4.0
