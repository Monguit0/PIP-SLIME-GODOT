extends Area2D
## Flecha del arquero. Normal: 220 px/s, 1 de daño, se clava. Cargada: 380 px/s, 3 de daño, atraviesa.

const GRAV := 110.0  # caída suave: el tiro normal va casi recto

var power := false
var face := 1
var vel := Vector2.ZERO
var stuck := false
var life := 0.0
var hit_list: Array = []
var dmg := 1


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(5, true)  # blanco de flechas de los slimes
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 4)
	shape.shape = rect
	add_child(shape)
	vel = Vector2(face * (380.0 if power else 220.0), 0.0)
	dmg = 3 if power else 1
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)


func _physics_process(dt: float) -> void:
	life += dt
	if stuck:
		modulate.a = clampf((1.2 - life) / 0.4, 0.0, 1.0)
		if life > 1.2:
			queue_free()
		return
	if not power:
		vel.y += GRAV * dt
	position += vel * dt
	rotation = vel.angle()
	if life > 2.0:
		queue_free()
	if power and Engine.get_physics_frames() % 2 == 0:
		Fx.burst(get_parent(), global_position, 1, [Color("7fd6ff")], 5.0, 0.0, 0.15)


func _on_body(_b: Node) -> void:
	if stuck:
		return
	stuck = true
	life = 0.8
	set_deferred("monitoring", false)
	Fx.burst(get_parent(), global_position, 3, [Color("c8b090")], 30.0, 20.0)


func _on_area(a: Area2D) -> void:
	if stuck:
		return
	var enemy := a.get_parent()
	if enemy == null or not enemy.has_method("take_hit") or enemy in hit_list:
		return
	hit_list.append(enemy)
	enemy.call("take_hit", dmg, face)
	if not power:
		queue_free()


func _draw() -> void:
	var c := Color("e8e0c8") if not power else Color("bff0ff")
	draw_line(Vector2(-5, 0), Vector2(3, 0), Color("8a5a2b"), 1.0)
	draw_rect(Rect2(3, -1, 2, 2), c)
	draw_rect(Rect2(-6, -1, 2, 2), Color("d9473f"))
