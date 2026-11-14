extends CharacterBody2D
## Mini hongo que invoca el hongo esporero: corre por el piso hacia el héroe más cercano y lo lastima al
## tocarlo (y ahí revienta). Muere de un golpe y dura unos segundos.

const GRAV := 900.0
const LIFE := 6.0
const SPEED := 58.0
const DIR := "res://assets/sprites/bosque/hongo/walk/"

var kind := "mini"
var minion := true
var zone := 0
var min_x := 0.0
var max_x := 99999.0
var dead := false
var spawn := 0.0
var windup := 0.0
var face := 1.0
var t := 0.0
var hop := 0.0
var sprite: Sprite2D
var frames: Array = []
var game


func _ready() -> void:
	add_to_group("enemigos")
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	floor_snap_length = 2.0
	game = get_tree().get_first_node_in_group("juego")
	var i := 0
	while ResourceLoader.exists("%sframe_%03d.png" % [DIR, i]):
		frames.append(load("%sframe_%03d.png" % [DIR, i]))
		i += 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(5, 8)
	shape.shape = rect
	shape.position = Vector2(0, -4)
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-32, -62)
	sprite.scale = Vector2(0.2, 0.2)
	add_child(sprite)
	velocity.y = -150.0
	Fx.burst(get_parent(), global_position, 5, [Pal.L, Color("863cac")], 40.0, 30.0, 0.3, 200.0)


func hit_rect() -> Rect2:
	return Rect2(global_position.x - 4, global_position.y - 10, 8, 10)


func _physics_process(dt: float) -> void:
	if dead:
		return
	t += dt
	var best: Player = null
	var bd := 1e9
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p != null and not p.dead:
			var d := absf(p.global_position.x - global_position.x)
			if d < bd:
				bd = d
				best = p
			if p.box().intersects(hit_rect()):
				p.hurt(global_position.x, 1, self)
				_pop()
				return
	if best != null and is_on_floor():
		face = signf(best.global_position.x - global_position.x)
	velocity.x = face * SPEED
	velocity.y = minf(velocity.y + GRAV * dt, 280.0)
	move_and_slide()
	if position.x < min_x or position.x > max_x or t > LIFE:
		_pop()
		return
	if not frames.is_empty():
		sprite.texture = frames[int(t * 16.0) % frames.size()]
	sprite.scale = Vector2(0.2 * (1.0 if face >= 0.0 else -1.0), 0.2)
	sprite.modulate = Color.WHITE if t < LIFE - 1.0 or int(t * 14.0) % 2 == 0 else Color(1, 1, 1, 0.4)


func _pop() -> void:
	if dead:
		return
	dead = true
	Fx.burst(get_parent(), global_position + Vector2(0, -5), 7, [Pal.L, Color("863cac"), Pal.W], 60.0, 30.0, 0.3, 220.0)
	Snd.play("baba", {"rate": 1.8, "vol": 0.4})
	queue_free()


func take_hit(_dmg: int, _from_dir: int, _how: String = "arrow") -> void:
	_pop()


func parried(_d: float, _t: float) -> void:
	_pop()


func apply_burn(_long: bool = false, _green: bool = false) -> void:
	_pop()


func apply_venom() -> void:
	_pop()
