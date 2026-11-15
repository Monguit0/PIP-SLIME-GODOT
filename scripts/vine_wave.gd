extends Node2D
## Las enredaderas de la planta carnívora: brotan del piso una atrás de otra, como una ola que avanza.
## Lastiman una vez a cada héroe que agarran (pueden ser varios) y se saltan. Recorren REACH píxeles.
## El dibujo de cada enredadera es de PixelLab (assets/sprites/bosque/enredadera).

const REACH := 120.0
const SPEED := 115.0
const LEN := 46.0     # largo del tramo de enredaderas que está afuera
const HIGH := 16.0
const STEP := 12.0    # una enredadera cada tantos píxeles
const SCALE := 0.4
const DIR := "res://assets/sprites/bosque/enredadera/"

var dir := 1.0
var floor_y := 128.0
var gone := 0.0
var t := 0.0
var hit: Array = []
var src
var frames: Array = []
var born := 0   # cuántas enredaderas ya brotaron


func _ready() -> void:
	z_index = 3
	add_to_group("enredaderas")
	for i in 9:
		frames.append(load("%sframe_%03d.png" % [DIR, i]))
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
	# cada enredadera que brota levanta tierra
	while 6.0 + born * STEP <= head:
		var at := Vector2(global_position.x + dir * (6.0 + born * STEP), floor_y)
		Fx.burst(get_parent(), at, 4, [Color("5a3a25"), Color("7e5531"), Color("41ce11")], 70.0, 70.0, 0.35, 320.0)
		Fx.dust(get_parent(), at, 2, 20.0, 6.0, 1.6, Color("5a3a25"))
		if born % 2 == 0:
			Snd.play("paso", {"rate": 0.6, "vol": 0.5})
			Fx.shake(0.8, 0.08)
		born += 1
	if tail >= head:
		return
	var x0 := global_position.x + dir * tail
	var x1 := global_position.x + dir * head
	var area := Rect2(minf(x0, x1), floor_y - HIGH, absf(x1 - x0), HIGH)
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p != null and not p.dead and not hit.has(p) and p.box().intersects(area):
			hit.append(p)
			if p.hurt(global_position.x + dir * (tail - 4.0), 1, self):
				Fx.burst(get_parent(), p.global_position + Vector2(0, -6), 5, [Color("41ce11"), Pal.W], 60.0, 40.0, 0.3, 200.0)


func _draw() -> void:
	var life := LEN / SPEED
	var base_y := floor_y - global_position.y
	var i := 0
	while 6.0 + i * STEP <= REACH:
		var x := 6.0 + i * STEP
		var u := (gone - x) / SPEED     # hace cuánto brotó esta
		i += 1
		if u < 0.0 or u > life:
			continue
		# sale de la tierra de un saque, se sacude y se vuelve a hundir
		var r := minf(1.0, u / 0.07)
		r = minf(r, clampf((life - u) / 0.12, 0.0, 1.0))
		r = 1.0 - (1.0 - r) * (1.0 - r)
		var over := 1.0 + 0.18 * sin(clampf(u / 0.16, 0.0, 1.0) * PI)   # rebote al salir
		var tex: Texture2D = frames[(int(u * 22.0) + i * 3) % frames.size()]
		var rows := 63.0 * r
		var fl := dir if i % 2 == 0 else -dir
		draw_set_transform(Vector2(dir * x, base_y), 0.0, Vector2(SCALE * fl, SCALE * over))
		draw_texture_rect_region(tex, Rect2(-32, -rows, 64, rows), Rect2(0, 0, 64, rows))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
