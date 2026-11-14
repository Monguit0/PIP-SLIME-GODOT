extends Node2D
## El hacha que lanza el esqueleto hachero: sale girando, se frena a unos 90 px y vuelve a su mano como un
## búmeran. Lastima a la ida y a la vuelta (una vez por tramo a cada héroe) y atraviesa las plataformas.
## Si el dueño muere con el hacha en el aire, cae al piso y se apaga.

const TEX := preload("res://assets/sprites/skel/axe_thrown.png")

var game
var thrower: Node2D
var dir := 1.0
var vx := 300.0
var back := false
var lost := false
var vy := 0.0
var t := 0.0
var hit: Array = []
var whoosh := 0.0


func _ready() -> void:
	z_index = 4
	add_to_group("hachas")


func _physics_process(dt: float) -> void:
	t += dt
	queue_redraw()
	if lost:
		vy += 500.0 * dt
		position += Vector2(dir * 30.0, vy) * dt
		if position.y > 126.0 or t > 3.0:
			Fx.dust(get_parent(), position, 2, 16.0, 3.0, 1.2, Pal.SS)
			queue_free()
		return
	if thrower == null or not is_instance_valid(thrower) or thrower.dead:
		lost = true
		return
	whoosh -= dt
	if whoosh <= 0.0:
		whoosh = 0.16
		Snd.play("tajo", {"rate": 1.6, "vol": 0.22})
	if not back:
		# la ida: sale fuerte y se va frenando
		position.x += dir * vx * dt
		vx -= 500.0 * dt
		if vx <= 0.0:
			back = true
			hit.clear()
			vx = 0.0
			Fx.twinkle(get_parent(), global_position, Pal.W, 3.0, 0.14)
	else:
		# la vuelta: acelera hacia la mano del dueño, esté donde esté
		var to: Vector2 = thrower.global_position + Vector2(0, -11) - global_position
		vx = minf(300.0, vx + 620.0 * dt)
		if to.length() < 8.0:
			thrower.axe_back()
			queue_free()
			return
		position += to.normalized() * vx * dt
	if int(t * 30.0) % 2 == 0:
		Fx.part(get_parent(), global_position, Vector2.ZERO, 0.0, 0.12, Pal.S if back else Pal.W)
	var b := Rect2(global_position.x - 7.0, global_position.y - 6.0, 14, 12)
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p != null and not p.dead and not hit.has(p) and p.box().intersects(b):
			hit.append(p)
			if p.hurt(global_position.x - dir * 6.0 * (-1.0 if back else 1.0), 1, self):
				Fx.hitstop(0.04)


func _draw() -> void:
	# la misma hacha que lleva en la mano (recortada de su dibujo), girando sobre el medio del mango,
	# con dos sombras de giro detrás para que se lea la vuelta
	var spin := t * 20.0 * dir * (-1.0 if back else 1.0)
	for i in 3:
		var k := 2 - i
		draw_set_transform(Vector2.ZERO, spin - k * 0.55 * dir * (-1.0 if back else 1.0), Vector2.ONE)
		draw_texture_rect(TEX, Rect2(-10.5, -4.5, 21, 9), false, Color(1, 1, 1, [1.0, 0.35, 0.15][k]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
