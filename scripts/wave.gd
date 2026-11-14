extends Node2D
## Onda de choque del Mega Caballero cuando cae de un salto: corre por el piso y hay que saltarla.

const GROUND := 128.0

var game  # main.gd
var dir := 1
var spd := 150.0
var min_x := 0.0
var max_x := 9999.0
var hero := false  # la devolvió el parry: ahora le pega al jefe


func _ready() -> void:
	z_index = 4


func _physics_process(dt: float) -> void:
	position.x += dir * spd * dt
	position.y = 0.0
	if randf() < 0.45:
		Fx.dust(get_parent(), Vector2(position.x - dir * 3.0, GROUND), 1, 18.0, 6.0, randf_range(1.2, 2.0), Pal.S, -dir)
	if randf() < 0.35:
		Fx.part(get_parent(), Vector2(position.x + randf_range(-2, 2), GROUND - 5), Vector2(-dir * 30.0, -40.0), 160.0, 0.3, Pal.C if randf() < 0.6 else Pal.W)
	if position.x < min_x - 4.0 or position.x > max_x + 4.0:
		queue_free()
		return
	var r := Rect2(position.x - 4, GROUND - 7, 8, 7)
	if hero:
		var b = game.boss if game != null else null
		if b != null and is_instance_valid(b) and b.active() and b.body().intersects(r):
			b.damage(2, position.x, GROUND - 6.0)
			queue_free()
		queue_redraw()
		return
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p != null and not p.dead and p.box().intersects(r) and p.hurt(position.x - dir * 10.0, 1, self):
			queue_free()
			break
	queue_redraw()


## El parry del caballero la devuelve, más rápida, contra el jefe.
func parried(d: float, _t: float) -> void:
	dir = 1 if d > 0.0 else -1
	spd *= 1.3
	hero = true
	position.x += dir * 6.0
	min_x -= 400.0
	max_x += 400.0


## El escudo la frena: se deshace en chispas.
func blocked(_d: float) -> void:
	Fx.burst(get_parent(), Vector2(position.x, GROUND - 4), 8, [Pal.C, Pal.W], 70.0, 30.0, 0.3, 200.0)
	queue_free()


## Cresta de energía a medio píxel: el frente empinado, la cola larga, borde blanco y espuma que titila.
func _draw() -> void:
	var ph := Time.get_ticks_msec() / 1000.0
	var i := -9
	while i <= 6:
		var x := i * 0.5 * dir  # i positivo: el frente
		var u := (i + 9) / 15.0  # 0 cola, 1 frente
		var h := 7.0 * pow(sin(u * PI * 0.92), 1.4) * (0.55 + 0.45 * u)
		h += 0.5 if int(ph * 30.0 + i) % 5 == 0 else 0.0
		h = roundf(h * 2.0) / 2.0
		if h >= 0.5:
			var top := GROUND - h
			draw_rect(Rect2(x, top, 0.5, h), Pal.RAMP_C[1] if u < 0.35 else Pal.C)
			draw_rect(Rect2(x, GROUND - minf(h, 1.5), 0.5, minf(h, 1.5)), Pal.RAMP_B[1])
			draw_rect(Rect2(x, top, 0.5, 0.5), Pal.W if u > 0.3 else Pal.RAMP_C[3])
			if h > 3.0 and u > 0.45:
				draw_rect(Rect2(x, top + 1.0, 0.5, 0.5), Pal.RAMP_C[3])
		i += 1
	# espuma arriba del frente
	for k in 3:
		if int(ph * 18.0 + k * 2) % 3 != 0:
			draw_rect(Rect2(dir * (1.0 + k * 0.5), GROUND - 7.5 - k * 0.5 - (int(ph * 24.0 + k) % 2) * 0.5, 0.5, 0.5), Pal.W)
