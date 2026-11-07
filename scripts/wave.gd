extends Node2D
## Onda de choque del Mega Caballero cuando cae de un salto: corre por el piso y hay que saltarla.

const GROUND := 128.0

var game  # main.gd
var dir := 1
var spd := 150.0
var min_x := 0.0
var max_x := 9999.0


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
	var p: Player = game.player if game != null else null
	if p != null and not p.dead and p.box().intersects(Rect2(position.x - 4, GROUND - 7, 8, 7)) and p.hurt(position.x - dir * 10.0):
		queue_free()
	queue_redraw()


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
