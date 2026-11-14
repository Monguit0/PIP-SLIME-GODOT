extends Node2D
## Flecha del esqueleto arquero (mobShoot del original): 205 px/s casi recta, lastima a Pip.
## Se clava donde pega (piso, paredes, portones y plataformas desde arriba), vibra y queda un rato.
## Se puede esquivar saltando o con el dash.

const Stick := preload("res://scripts/stick.gd")
const TIP := 3.0
const STUCK_TIME := 2.5

var face := 1.0
var game  # main.gd
var vel := Vector2.ZERO
var life := 0.0
var stuck := false
var wobble := 0.0
var prev_tip := Vector2.ZERO
var stuck_on: Object = null
var stuck_pos := Vector2.ZERO


var aim := Vector2.ZERO  # si viene, la dirección del tiro (las tres flechas del arquero: arriba, medio y abajo)
var hero := false  # la devolvió el parry: ahora le pega a los bichos y al jefe
var hero_dmg := 2  # lo que pega devuelta (1 la de los esqueletos del Nigromante)
var hit_list: Array = []


func _ready() -> void:
	z_index = 3
	add_to_group("flechas_malas")
	vel = aim * 205.0 if aim != Vector2.ZERO else Vector2(face * 205.0, -10.0)
	rotation = vel.angle()
	prev_tip = global_position - vel.normalized() * 6.0


func _physics_process(dt: float) -> void:
	life += dt
	if stuck:
		if wobble > 0.0:
			wobble = maxf(0.0, wobble - dt / 0.35)
			queue_redraw()
		var lift := Stick.gate_lift(stuck_on)
		if lift > 0.0:
			global_position.y = stuck_pos.y - lift
			if global_position.y < Stick.GATE_TOP + 3.0:
				queue_free()
				return
		modulate.a = clampf(1.0 - (life - STUCK_TIME) / 0.4, 0.0, 1.0)
		if life > STUCK_TIME + 0.4:
			queue_free()
		return
	vel.y += 60.0 * dt
	position += vel * dt
	rotation = vel.angle()
	var dir := vel.normalized()
	var tip := global_position + dir * TIP
	var hit := Stick.cast(self, prev_tip, tip)
	prev_tip = tip
	if not hit.is_empty():
		var at: Vector2 = hit["position"]
		stuck = true
		life = 0.0
		wobble = 1.0
		stuck_on = hit["collider"]
		global_position = (at - dir * TIP).round()
		stuck_pos = global_position
		Snd.play("clavar", {"vol": 0.4})
		Stick.dust(get_parent(), at, hit["normal"], stuck_on)
		queue_redraw()
		return
	if randf() < 0.5:
		Fx.part(get_parent(), global_position - Vector2(face * 4.0, 0), Vector2.ZERO, 0.0, 0.12, Pal.L)
	if life > 1.8:
		queue_free()
		return
	if hero:
		_hit_foes()
		return
	# en la campaña hay un solo héroe; en el modo Villano son cuatro
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p != null and not p.dead and p.box().has_point(global_position + Vector2(face * 2.0, 0)):
			if p.hurt(global_position.x - face * 10.0, 1, self):
				Fx.burst(get_parent(), global_position, 4, [Pal.L, Pal.W], 60.0, 20.0, 0.25, 200.0)
				queue_free()
				return


## devuelta por el parry: le pega a lo que encuentre (2 de daño)
func _hit_foes() -> void:
	var tip := global_position + vel.normalized() * TIP
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e in hit_list or e.dead or e.spawn > 0.0 or not e.hit_rect().grow(1.0).has_point(tip):
			continue
		hit_list.append(e)
		e.take_hit(hero_dmg, int(signf(vel.x)), "arrow")
		queue_free()
		return
	var b = game.boss if game != null else null
	if b != null and is_instance_valid(b) and b.active() and b.body().has_point(tip):
		b.damage(hero_dmg, tip.x, tip.y)
		queue_free()


## El parry del caballero la devuelve, más rápida y hacia arriba.
func parried(_d: float, _t: float) -> void:
	if stuck or hero:
		return
	hero = true
	face = -face
	vel = Vector2(-vel.x * 1.4, -20.0)
	rotation = vel.angle()
	life = 0.0
	position.x += face * 4.0
	Fx.twinkle(get_parent(), global_position, Pal.Y, 4.0, 0.16)


## El escudo la frena: rebota y se cae girando.
func blocked(_d: float) -> void:
	if stuck or hero:
		return
	Snd.play("clavar", {"rate": 1.6, "vol": 0.5})
	Fx.burst(get_parent(), global_position, 5, [Pal.W, Pal.S], 60.0, 30.0, 0.25, 200.0)
	queue_free()


## A medio píxel como la de Pip: palo viejo, plumas grises y punta con brillo verde (los ojos del esqueleto).
func _draw() -> void:
	if stuck:
		# la punta quedó adentro: se ve el palo vibrando desde ahí
		var w := sin(life * 70.0) * 0.22 * wobble
		draw_set_transform(Vector2(TIP, 0), w, Vector2.ONE)
		_body(-TIP, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_body(0.0, true)


func _body(ox: float, head: bool) -> void:
	draw_rect(Rect2(ox - 5.0, -0.5, 8.0, 0.5), Color("8f7a50"))
	draw_rect(Rect2(ox - 5.0, 0.0, 8.0, 0.5), Color("4f4128"))
	draw_rect(Rect2(ox - 6.5, -1.5, 1.5, 0.5), Pal.S)
	draw_rect(Rect2(ox - 6.0, -1.0, 2.0, 0.5), Pal.S)
	draw_rect(Rect2(ox - 6.0, 0.5, 2.0, 0.5), Pal.SS)
	draw_rect(Rect2(ox - 6.5, 1.0, 1.5, 0.5), Pal.SS)
	if not head:
		return
	draw_rect(Rect2(3.0, -1.0, 1.0, 2.0), Pal.RAMP_L[0])
	draw_rect(Rect2(3.0, -1.0, 1.0, 0.5), Pal.RAMP_L[2])
	draw_rect(Rect2(4.0, -0.5, 1.0, 1.0), Pal.RAMP_L[1])
	draw_rect(Rect2(4.0, -0.5, 0.5, 0.5), Pal.RAMP_L[4])
	draw_rect(Rect2(5.0, -0.5, 0.5, 0.5), Pal.RAMP_L[2])
