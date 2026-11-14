extends Node2D
## Bola de fuego del mago (castFire, stepSpell y explodeSpell del original): sale derecho a 175 px/s
## ondulando un poco, y explota al tocar un enemigo, al jefe, una pared o el piso, o al segundo y pico.
## Al que toca le pega fuerte, a los de alrededor uno menos, y todos quedan quemándose.
## La del Nigromante es verde (fuego de almas). Dibujada a medio píxel, con llamas que cambian de forma.

const Stick := preload("res://scripts/stick.gd")
const Pix := preload("res://scripts/pix.gd")
const SPEED := 175.0
const LIFE := 1.15
const R := 19.0
const R_BIG := 30.0       # carta "gran bola"
const GROUND := 128.0

var face := 1
var evo := false          # Nigromante: verde
var big := false          # carta "gran bola"
var long_burn := false    # carta "brasas eternas"
var dmg := 2
var game                  # main.gd
var t := 0.0
var trail := 0.0
var prev := Vector2.ZERO
var done := false
var seed_k := 0.0


func _ready() -> void:
	z_index = 4
	add_to_group("hechizos")
	prev = global_position - Vector2(face * 8.0, 0)
	seed_k = randf() * 10.0


## los cuatro tonos del fuego, del centro hacia afuera
func cols() -> Array:
	return [Pal.RAMP_L[4], Pal.L, Pal.G, Pal.RAMP_G[1]] if evo else [Pal.RAMP_Y[4], Pal.Y, Pal.O, Pal.R]


func _col(k: float) -> Color:
	var c := cols()
	if evo:
		return c[0] if k < 0.3 else (c[1] if k < 0.65 else c[2])
	return c[0] if k < 0.25 else (c[1] if k < 0.55 else (c[2] if k < 0.85 else c[3]))


func _physics_process(dt: float) -> void:
	if done:
		return
	t += dt
	position.x += face * SPEED * dt
	position.y += sin(t * 16.0) * 7.0 * dt
	queue_redraw()
	# estela: brasas que quedan atrás y suben, y cada tanto una chispa que se cae
	trail -= dt
	while trail <= 0.0:
		trail += 0.016
		Fx.part(get_parent(), global_position + Vector2(-face * 3.0 + randf_range(-1.5, 1.5), randf_range(-2, 2)),
			Vector2(-face * randf_range(20, 50), -randf_range(10, 35)), -30.0, 0.3, _col(randf()), 2 if randf() < 0.3 else 1)
	if Engine.get_physics_frames() % 3 == 0:
		Fx.streak(get_parent(), global_position + Vector2(-face * 4.0, randf_range(-2, 2)), Vector2(-face * 90.0, randf_range(-10, 10)), 0.12, _col(0.4 + 0.5 * randf()), 6.0)
	if Engine.get_physics_frames() % 7 == 0:
		Fx.part(get_parent(), global_position, Vector2(-face * 20.0, 10), 160.0, 0.35, cols()[2])

	# la caja baja hasta casi el piso: los slimes son petisos y la bola va a la altura del pecho
	var box := Rect2(global_position - Vector2(3, 4), Vector2(6, 13))
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.dead or e.spawn > 0.0 or not e.has_method("hit_rect"):
			continue
		if e.hit_rect().intersects(box):
			explode(e)
			return
	var b = game.boss if game != null else null
	if b != null and is_instance_valid(b) and b.active() and b.body().intersects(box):
		explode(b)
		return
	var hit := Stick.cast(self, prev, global_position + Vector2(face * 3.0, 0))
	prev = global_position
	if not hit.is_empty() or global_position.y >= GROUND - 1.0 or t > LIFE:
		explode(null)
		return
	# monedas al paso
	for coin in get_tree().get_nodes_in_group("monedas"):
		if coin.can_take() and absf(coin.global_position.x - global_position.x) < 6.0 and absf(coin.global_position.y - global_position.y) < 6.0:
			coin.take()


static func _near(p: Vector2, r: Rect2, rad: float) -> bool:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return dx * dx + dy * dy <= rad * rad


## La explosión: congelado, luz, bollos de fuego, anillos, chispas que caen, humo y temblor; daño en el
## área y todos los que agarra quedan quemándose.
func explode(direct: Object) -> void:
	if done:
		return
	done = true
	var rad := R_BIG if big else R
	var at := global_position
	var c := cols()
	var par := get_parent()
	Snd.play("explotar", {"rate": 0.65 if big else 0.8})
	Snd.play("fuego", {"rate": 0.8, "vol": 0.6})
	Snd.boom(0.6 if big else 0.4)
	Fx.hitstop(0.04)
	Fx.shake(3.5 if big else 2.5, 0.18)
	Fx.kick(Vector2(face, 0), 1.5)
	blast(par, at, rad, c)
	Fx.ring(par, at, c[1], 0.0, rad, 1.0, 0.3)
	Fx.ring(par, at, c[2], -0.05, rad * 1.25, 1.0, 0.32)
	if big:
		Fx.ring(par, at, c[3], -0.1, rad * 1.5, 1.0, 0.36)
	Fx.burst(par, at, 28 if big else 18, [c[0], c[1], c[2], c[3]], 130.0 * rad / R, 30.0, 0.45, 140.0)
	for i in 6:
		var a := TAU * i / 6.0 + randf() * 0.5
		Fx.streak(par, at, Vector2(cos(a), sin(a)) * randf_range(140, 220) * rad / R, 0.16, c[1] if i % 2 == 0 else c[0], 9.0)
	for i in 3:
		Fx.twinkle(par, at + Vector2(randf_range(-rad, rad) * 0.6, randf_range(-rad, rad) * 0.5), c[0], randf_range(2.5, 4.0), 0.2 + 0.05 * i)
	# humo que queda subiendo, y si explotó cerca del piso, tierra chamuscada que salta
	Fx.dust(par, at + Vector2(0, 2), 5, rad * 1.2, 14.0, 2.4, Pal.SS)
	if at.y > GROUND - rad:
		Fx.chunks(par, Vector2(at.x, GROUND - 1.0), 5, [Pal.SS, Pal.D, c[3]], 70.0, 50.0, GROUND - 1.0)
		Fx.shock(par, Vector2(at.x, GROUND - 1.0), c[2], rad, 0.3)

	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.dead or e.spawn > 0.0 or not e.has_method("hit_rect"):
			continue
		if e != direct and not _near(at, e.hit_rect(), rad):
			continue
		var side := int(signf(e.global_position.x - at.x))
		if side == 0:
			side = face
		e.take_hit(dmg if e == direct else maxi(1, dmg - 1), side, "fire")
		if not e.dead and e.has_method("apply_burn"):
			e.apply_burn(long_burn, evo)
	var b = game.boss if game != null else null
	if b != null and is_instance_valid(b) and b.active() and (b == direct or _near(at, b.body(), rad)):
		b.damage(dmg if b == direct else maxi(1, dmg - 1), at.x, at.y)
		if b.has_method("apply_burn"):
			b.apply_burn(long_burn, evo)
	# lo que venía cayendo cerca también vuela
	for h in get_tree().get_nodes_in_group("peligros"):
		if h.phase == "fall" and _near(at, h.box(), rad * 0.7):
			h.smash()
	queue_free()


## el fogonazo: un nodo que dura un instante, con discos que se achican del blanco al color de afuera
static func blast(par: Node, at: Vector2, rad: float, c: Array) -> void:
	var n := Node2D.new()
	n.z_index = 5
	n.global_position = at
	par.add_child(n)
	var st := {"t": 0.0}
	var lobes: Array = []
	for i in 5:
		var a := TAU * i / 5.0 + randf()
		lobes.append([Vector2(cos(a), sin(a) * 0.8) * rad * randf_range(0.3, 0.55), rad * randf_range(0.35, 0.5)])
	n.draw.connect(func() -> void:
		var k: float = st.t / 0.22
		if k >= 1.0:
			return
		var grow := 0.55 + 0.45 * sqrt(k)
		var col: Color = c[0] if k < 0.2 else (c[1] if k < 0.45 else (c[2] if k < 0.75 else c[3]))
		if k < 0.75:
			Pix.disc(n, Vector2.ZERO, rad * 0.62 * grow, col)
			for l in lobes:
				Pix.disc(n, l[0] * grow, l[1] * (1.0 - 0.4 * k), col)
			if k < 0.45:
				Pix.disc(n, Vector2.ZERO, rad * 0.34 * grow, c[0])
		else:
			Pix.disc_dither(n, Vector2.ZERO, rad * 0.6 * grow, col)
			for l in lobes:
				Pix.disc_dither(n, l[0] * grow, l[1] * 0.6, col, true)
	)
	var tw := n.create_tween()
	tw.tween_method(func(v: float) -> void:
		st.t = v
		n.queue_redraw(), 0.0, 0.22, 0.22)
	tw.tween_callback(n.queue_free)


## Núcleo blanco, llama de tres tonos que late y una cola de lenguas hacia atrás; alrededor, un halo en damero.
func _draw() -> void:
	var c := cols()
	var b := 1.5 if big else 0.0
	var fl := int((t + seed_k) * 24.0) % 2
	var f := float(face)
	Pix.disc_dither(self, Vector2.ZERO, 7.0 + b + fl, c[3], true)
	Pix.disc_dither(self, Vector2.ZERO, 5.0 + b, c[2])
	# cola: tres lenguas que se alternan
	for i in 3:
		var w := sin((t + seed_k) * 30.0 + i * 2.1)
		var back := Vector2(-f * (4.0 + 2.5 * i + b), w * (1.0 + 0.5 * i))
		Pix.disc(self, back, maxf(0.5, 2.5 - 0.7 * i + b * 0.5), c[3] if i == 2 else c[2])
	Pix.disc(self, Vector2.ZERO, 3.5 + b, c[2])
	Pix.disc(self, Vector2(f * 0.5, 0), 2.5 + b, c[1])
	Pix.disc(self, Vector2(f * 1.0, -0.5 * fl), 1.5 + b * 0.5, c[0])
