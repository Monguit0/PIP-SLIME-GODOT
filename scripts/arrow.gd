extends Area2D
## Flecha del arquero. Normal: 220 px/s, 1 de daño, se clava. Cargada: 380 px/s, 3 de daño, atraviesa.
## Con veneno (Cazador) deja una estela verde y envenena al blanco. También junta monedas al pasar.

const GRAV := 110.0  # caída suave: el tiro normal va casi recto

var power := false
var face := 1
var vy0 := 0.0       # la flecha triple sale abierta (arriba y abajo)
var delay := 0.0     # la segunda flecha del Cazador sale un instante después
var venom := false
var dmg := 1
var vel := Vector2.ZERO
var stuck := false
var life := 0.0
var hit_list: Array = []
var trail := 0.0


func _ready() -> void:
	add_to_group("flechas")
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(5, true)  # blanco de flechas de los slimes y del jefe
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 4)
	shape.shape = rect
	add_child(shape)
	vel = Vector2(face * (380.0 if power else 220.0), vy0)
	rotation = vel.angle()
	if delay > 0.0:
		visible = false
		monitoring = false
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)


func _physics_process(dt: float) -> void:
	if delay > 0.0:
		delay -= dt
		if delay <= 0.0:
			visible = true
			monitoring = true
		return
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
	trail -= dt
	if trail <= 0.0:
		trail = 0.012 if power else 0.02
		var c := Pal.L if venom else (Pal.C if randf() < 0.5 else Pal.W) if power else Pal.SS
		Fx.part(get_parent(), global_position - Vector2(face * 4, 0), Vector2(-face * 20.0 if power else 0.0, randf_range(-8, 8) if power else 0.0), 0.0, 0.22 if power else 0.14, c)
	# monedas al paso
	for coin in get_tree().get_nodes_in_group("monedas"):
		if coin.can_take() and absf(coin.global_position.x - global_position.x) < 5.0 and absf(coin.global_position.y - global_position.y) < 5.0:
			coin.take()


func _on_body(_b: Node) -> void:
	if stuck:
		return
	stuck = true
	life = 0.8
	set_deferred("monitoring", false)
	Snd.play("clavar", {"vol": 0.6})
	Fx.burst(get_parent(), global_position, 3, [Color("c8b090")], 30.0, 20.0)


func _on_area(a: Area2D) -> void:
	if stuck or delay > 0.0:
		return
	var enemy := a.get_parent()
	if enemy == null or not enemy.has_method("take_hit") or enemy in hit_list:
		return
	hit_list.append(enemy)
	if venom and enemy.has_method("apply_venom"):
		enemy.call("apply_venom")
	enemy.call("take_hit", dmg, face, "arrow")
	if power:
		Fx.burst(get_parent(), global_position, 5, [Pal.C, Pal.W, Pal.O], 50.0, 20.0, 0.3, 200.0)
	else:
		queue_free()


func _draw() -> void:
	var c := Color("e8e0c8") if not power else Color("bff0ff")
	draw_line(Vector2(-5, 0), Vector2(3, 0), Color("8a5a2b"), 1.0)
	draw_rect(Rect2(3, -1, 2, 2), c)
	draw_rect(Rect2(-6, -1, 2, 2), Pal.L if venom else Color("d9473f"))
	if venom:
		draw_rect(Rect2(-1, -1, 4, 0.5), Pal.L)
