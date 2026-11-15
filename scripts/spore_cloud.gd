extends Node2D
## La nube venenosa que deja el hongo al reventar: grande, queda unos segundos y lastima al héroe que se
## queda adentro. El dibujo es de PixelLab (assets/sprites/bosque/nube): varios copos que hierven y al
## final se deshacen.

const LIFE := 4.0
const RAD := 36.0
const TICK := 0.7
const END := 0.55          # lo que tarda en deshacerse
const DIR := "res://assets/sprites/bosque/nube/"
const LOOP := [0, 1, 2, 3, 2, 1]
# los copos: dónde va cada uno, su tamaño y su desfase
const PUFFS := [[-24.0, -9.0, 0.62, 0.0], [24.0, -10.0, 0.62, 0.5], [-9.0, -24.0, 0.6, 0.25], [12.0, -22.0, 0.56, 0.7], [0.0, -10.0, 0.78, 0.4]]

var t := 0.0
var hit := {}   # héroe -> cuándo puede volver a lastimarlo
var pulse := 0.0
var loop: Array = []
var fin: Array = []


func _ready() -> void:
	z_index = 3
	add_to_group("esporas")
	for i in 4:
		loop.append(load("%sloop/frame_%03d.png" % [DIR, i]))
	for i in 6:
		fin.append(load("%sfin/frame_%03d.png" % [DIR, i]))
	Snd.play("explotar", {"rate": 0.6, "vol": 0.6})
	Snd.play("fuego", {"rate": 0.5, "vol": 0.5})


func _physics_process(dt: float) -> void:
	t += dt
	pulse = maxf(0.0, pulse - dt * 4.0)
	queue_redraw()
	if t > LIFE:
		queue_free()
		return
	# esporas que suben y burbujas que revientan
	if Engine.get_physics_frames() % 2 == 0 and t < LIFE - END * 0.5:
		var a := randf() * TAU
		var r := sqrt(randf()) * RAD
		var at := global_position + Vector2(cos(a) * r, -12.0 + sin(a) * r * 0.5)
		Fx.part(get_parent(), at, Vector2(randf_range(-8, 8), -randf_range(8, 22)), -12.0, 0.7, [Color("9ffd4e"), Color("29da0c"), Color("1c822d")].pick_random())
	if Engine.get_physics_frames() % 22 == 0 and t < LIFE - END:
		var bx := randf_range(-RAD, RAD) * 0.8
		Fx.ring(get_parent(), global_position + Vector2(bx, -randf_range(4, 26)), Color("9ffd4e"), 0.0, 5.0, 0.8, 0.22)
	if t < 0.2 or t > LIFE - END * 0.6:
		return
	var area := Rect2(global_position.x - RAD, global_position.y - 34.0, RAD * 2.0, 36.0)
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p == null or p.dead or not p.box().intersects(area):
			continue
		if float(hit.get(p, -9.0)) + TICK <= t:
			hit[p] = t
			if p.hurt(global_position.x, 1, self):
				pulse = 1.0
				Fx.burst(get_parent(), p.global_position + Vector2(0, -10), 6, [Color("9ffd4e"), Color("29da0c")], 50.0, 30.0, 0.35, 100.0)


func _draw() -> void:
	var left := LIFE - t
	# nace de golpe, con rebote; late un poco; cuando lastima se hincha
	var grow := clampf(t / 0.22, 0.0, 1.0)
	var pop := 1.0 + sin(grow * PI) * 0.25 if grow < 1.0 else 1.0
	var k := grow * pop * (1.0 + pulse * 0.08)
	# la sombra verde en el piso
	var fade := clampf(left / END, 0.0, 1.0)
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, RAD * k, Color(0.16, 0.85, 0.05, 0.22 * fade))
	for i in PUFFS.size():
		var p: Array = PUFFS[i]
		var tex: Texture2D
		if left < END:
			tex = fin[clampi(int((1.0 - left / END) * fin.size()), 0, fin.size() - 1)]
		else:
			tex = loop[LOOP[int((t + float(p[3])) * 7.0) % LOOP.size()]]
		var s: float = float(p[2]) * k * (1.0 + 0.05 * sin(t * 3.0 + i * 1.7))
		var c := Vector2(float(p[0]) * k + sin(t * 1.3 + i) * 1.5, float(p[1]) * k - (1.0 - fade) * 6.0)
		draw_set_transform(c, 0.0, Vector2(s if i % 2 == 0 else -s, s))
		draw_texture(tex, Vector2(-32, -32), Color(1.0 + pulse * 0.5, 1.0 + pulse * 0.5, 1.0 + pulse * 0.5, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
