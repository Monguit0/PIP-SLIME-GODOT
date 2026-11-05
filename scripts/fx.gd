extends Node
## Juice: partículas, temblor de cámara, hitstop, estelas y textos. Se usa como autoload "Fx".

var shake_amount := 0.0
var shake_time := 0.0
var _hitstop := 0.0


func _process(dt: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if shake_time > 0.0:
		shake_time -= dt
		if cam:
			cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
		if shake_time <= 0.0 and cam:
			cam.offset = Vector2.ZERO


func shake(amount: float, time: float) -> void:
	shake_amount = maxf(shake_amount if shake_time > 0.0 else 0.0, amount)
	shake_time = maxf(shake_time, time)


func hitstop(time: float) -> void:
	if _hitstop > 0.0:
		return
	_hitstop = time
	Engine.time_scale = 0.05
	await get_tree().create_timer(time, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop = 0.0


## Chispas que salen para todos lados (up = empuje extra hacia arriba).
func burst(parent: Node, pos: Vector2, n: int, colors: Array, speed: float, up: float, life: float = 0.35) -> void:
	if parent == null:
		return
	for i in n:
		var p := Particle.new()
		p.position = pos
		p.color = colors[randi() % colors.size()]
		var ang := randf() * TAU
		p.vel = Vector2(cos(ang), sin(ang)) * speed * randf_range(0.4, 1.0) + Vector2(0, -up)
		p.life = life * randf_range(0.7, 1.2)
		parent.add_child(p)


func ring(parent: Node, pos: Vector2, color: Color) -> void:
	var r := Ring.new()
	r.position = pos
	r.color = color
	parent.add_child(r)


func afterimage(parent: Node, src: AnimatedSprite2D) -> void:
	var s := Sprite2D.new()
	s.texture = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	s.offset = src.offset
	s.flip_h = src.flip_h
	s.scale = src.scale
	s.global_position = src.global_position
	s.modulate = Color(0.5, 0.8, 1.0, 0.5)
	parent.add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.0, 0.2)
	t.tween_callback(s.queue_free)


func popup(parent: Node, pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 6)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	l.position = pos - Vector2(20, 10)
	l.size = Vector2(40, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 50
	parent.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y - 14, 0.6).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.3)
	t.tween_callback(l.queue_free)


class Particle extends Node2D:
	var vel := Vector2.ZERO
	var color := Color.WHITE
	var life := 0.35
	var t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(dt: float) -> void:
		t += dt
		vel.y += 300.0 * dt
		position += vel * dt
		modulate.a = 1.0 - t / life
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-0.5, -0.5, 1, 1), color)


class Ring extends Node2D:
	var color := Color.WHITE
	var t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(dt: float) -> void:
		t += dt
		if t > 0.25:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := 3.0 + t * 40.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 16, Color(color, 1.0 - t / 0.25), 1.0)
