extends Node2D
## Un hueso suelto de un esqueleto que revienta: vuela girando, rebota en el piso, queda un rato y se apaga.
## kind: "skull" (la calavera, con sus ojitos verdes que se apagan), "long" (un hueso largo), "rib" (una
## costilla curva) o "bit" (una astilla).

const C1 := Color("e0d7b9")
const C2 := Color("b5a98d")

var kind := "long"
var vel := Vector2.ZERO
var spin := 0.0
var floor_y := 128.0
var life := 1.6
var t := 0.0
var bounces := 0


func _ready() -> void:
	z_index = 2
	rotation = randf() * TAU


func _physics_process(dt: float) -> void:
	t += dt
	vel.y += 460.0 * dt
	position += vel * dt
	rotation += spin * dt
	if position.y >= floor_y - 1.0 and vel.y > 0.0:
		position.y = floor_y - 1.0
		if vel.y > 50.0 and bounces < 3:
			# rebota: cada vez más bajo, con un clic y polvo
			vel.y *= -0.45
			vel.x *= 0.7
			spin *= 0.6
			bounces += 1
			if kind == "skull" or bounces == 1:
				Fx.dust(get_parent(), Vector2(position.x, floor_y), 1, 14.0, 2.0, 1.0, Pal.SS)
			if kind == "skull":
				Snd.play("huesos", {"rate": 1.5 + bounces * 0.2, "vol": 0.3})
		else:
			vel = Vector2(move_toward(vel.x, 0.0, 200.0 * dt), 0.0)
			spin = move_toward(spin, 0.0, 30.0 * dt)
	if t > life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if t > life - 0.4 and int(t * 20.0) % 2 == 1:
		return
	match kind:
		"skull":
			draw_rect(Rect2(-2.5, -2.5, 5, 4), C1)
			draw_rect(Rect2(-1.5, 1.5, 3, 1.5), C2)
			var eye: Color = Pal.L if t < 0.7 else Pal.K
			draw_rect(Rect2(-1.5, -1, 1, 1), eye)
			draw_rect(Rect2(0.5, -1, 1, 1), eye)
		"long":
			draw_rect(Rect2(-3, -0.5, 6, 1), C1)
			draw_rect(Rect2(-3.5, -1, 1, 2), C1)
			draw_rect(Rect2(2.5, -1, 1, 2), C1)
		"rib":
			draw_rect(Rect2(-2, -1, 4, 0.5), C1)
			draw_rect(Rect2(-2.5, -0.5, 0.5, 1.5), C2)
			draw_rect(Rect2(2, -0.5, 0.5, 1.5), C2)
		_:
			draw_rect(Rect2(-1, -0.5, 2, 1), C2)
