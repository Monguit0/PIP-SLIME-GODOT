extends Area2D
## Flecha del arquero. Normal: 220 px/s, 1 de daño. Cargada: 380 px/s, 3 de daño, atraviesa enemigos.
## Con veneno (Cazador) deja una estela verde y envenena al blanco. También junta monedas al pasar.
## Se clava donde pega (piso, paredes, portones y plataformas desde arriba): la punta queda adentro,
## la flecha vibra un instante y queda ahí un rato. Si el portón sube, sube con él.

const GRAV := 110.0  # caída suave: el tiro normal va casi recto
const Stick := preload("res://scripts/stick.gd")
const STUCK_TIME := 3.0
const TIP := 3.0     # de dónde sale la punta (en el dibujo, desde el centro)

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
var prev_tip := Vector2.ZERO
var wobble := 0.0    # vibración al clavarse
var stuck_on: Object = null
var stuck_pos := Vector2.ZERO
var falling := false


func _ready() -> void:
	add_to_group("flechas")
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(5, true)  # blanco de flechas de los slimes, esqueletos y del jefe
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 4)
	shape.shape = rect
	add_child(shape)
	vel = Vector2(face * (380.0 if power else 220.0), vy0)
	rotation = vel.angle()
	# el primer rayo sale de atrás, del arco: así una pared pegada a Pip también la frena
	prev_tip = global_position - vel.normalized() * 8.0
	if delay > 0.0:
		visible = false
		monitoring = false
	area_entered.connect(_on_area)


func _physics_process(dt: float) -> void:
	if delay > 0.0:
		delay -= dt
		if delay <= 0.0:
			visible = true
			monitoring = true
			prev_tip = global_position - vel.normalized() * 8.0
		return
	life += dt
	if falling:
		# se soltó (el portón se abrió del todo): cae girando y se apaga
		vel.y += 500.0 * dt
		position += vel * dt
		rotation += face * 7.0 * dt
		modulate.a = clampf(1.0 - life / 0.5, 0.0, 1.0)
		if life > 0.5:
			queue_free()
		return
	if stuck:
		_stuck(dt)
		return
	if not power:
		vel.y += GRAV * dt
	position += vel * dt
	rotation = vel.angle()
	var dir := vel.normalized()
	var tip := global_position + dir * TIP
	var hit := Stick.cast(self, prev_tip, tip)
	prev_tip = tip
	if not hit.is_empty():
		_stick(hit, dir)
		return
	if life > 2.0:
		queue_free()
	trail -= dt
	if trail <= 0.0:
		trail = 0.012 if power else 0.02
		var c := Pal.L if venom else (Pal.C if randf() < 0.5 else Pal.W) if power else Pal.S
		var back := global_position - dir * 5.0
		if power:  # estela de energía: rayitas que quedan atrás y se enfrían
			Fx.streak(get_parent(), back + Vector2(0, randf_range(-1.5, 1.5)), -dir * 70.0 + Vector2(0, randf_range(-12, 12)), 0.2, c, 4.0)
		else:
			Fx.part(get_parent(), back, Vector2.ZERO, 0.0, 0.14, c)
		if venom and randf() < 0.5:
			Fx.part(get_parent(), back, Vector2(randf_range(-6, 6), 12), 60.0, 0.4, Pal.G, 1, 4)
	# monedas al paso
	for coin in get_tree().get_nodes_in_group("monedas"):
		if coin.can_take() and absf(coin.global_position.x - global_position.x) < 5.0 and absf(coin.global_position.y - global_position.y) < 5.0:
			coin.take()


## La punta entra en lo que tocó y la flecha queda clavada vibrando.
func _stick(hit: Dictionary, dir: Vector2) -> void:
	var at: Vector2 = hit["position"]
	stuck = true
	life = 0.0
	wobble = 1.0
	stuck_on = hit["collider"]
	global_position = (at - dir * TIP).round()
	stuck_pos = global_position
	set_deferred("monitoring", false)
	Snd.play("clavar", {"vol": 0.6})
	Stick.dust(get_parent(), at, hit["normal"], stuck_on)
	queue_redraw()


func _stuck(dt: float) -> void:
	if wobble > 0.0:
		wobble = maxf(0.0, wobble - dt / 0.35)
		queue_redraw()
	# clavada en un portón que sube: sube con las rejas, y se suelta al llegar al arco
	var lift := Stick.gate_lift(stuck_on)
	if lift > 0.0:
		global_position.y = stuck_pos.y - lift
		if global_position.y < Stick.GATE_TOP + 3.0:
			falling = true
			life = 0.0
			vel = Vector2(-face * 20.0, -30.0)
			return
	if life > STUCK_TIME:
		modulate.a = clampf(1.0 - (life - STUCK_TIME) / 0.5, 0.0, 1.0)
		if life > STUCK_TIME + 0.5:
			queue_free()


func _on_area(a: Area2D) -> void:
	if stuck or falling or delay > 0.0:
		return
	var enemy := a.get_parent()
	if enemy == null or not enemy.has_method("take_hit") or enemy in hit_list:
		return
	hit_list.append(enemy)
	if venom and enemy.has_method("apply_venom"):
		enemy.call("apply_venom")
	enemy.call("take_hit", dmg, face, "arrow")
	# la estrella del golpe la pone el enemigo; la cargada además larga chispas celestes al atravesar
	if power:
		var at := global_position + vel.normalized() * TIP
		Fx.burst(get_parent(), at, 5, [Pal.C, Pal.W, Pal.O], 60.0, 20.0, 0.3, 200.0)
		Fx.twinkle(get_parent(), at, Pal.C, 4.0, 0.16)
	else:
		queue_free()


## Flecha a medio píxel: palo de madera con luz arriba, plumas de dos tonos y punta de metal con brillo.
func _draw() -> void:
	if stuck:
		# vibra desde la punta, que quedó adentro (no se dibuja)
		var w := sin(life * 70.0) * 0.22 * wobble
		draw_set_transform(Vector2(TIP, 0), w, Vector2.ONE)
		_body(-TIP, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_body(0.0, true)


func _body(ox: float, head: bool) -> void:
	var fl := Pal.L if venom else Color("d9473f")
	var fl_dk := Pal.G if venom else Color("8a2430")
	draw_rect(Rect2(ox - 5.0, -0.5, 8.0, 0.5), Color("c08a4a"))  # palo: luz arriba
	draw_rect(Rect2(ox - 5.0, 0.0, 8.0, 0.5), Color("6b4220"))
	draw_rect(Rect2(ox - 6.5, -1.5, 1.5, 0.5), fl)  # plumas
	draw_rect(Rect2(ox - 6.0, -1.0, 2.0, 0.5), fl)
	draw_rect(Rect2(ox - 6.0, 0.5, 2.0, 0.5), fl_dk)
	draw_rect(Rect2(ox - 6.5, 1.0, 1.5, 0.5), fl_dk)
	if venom:
		draw_rect(Rect2(ox - 1.0, -1.0, 3.0, 0.5), Pal.L)  # gota de veneno en el palo
	if not head:
		return
	var m := Pal.RAMP_C if power else Pal.RAMP_S
	draw_rect(Rect2(3.0, -1.0, 1.0, 2.0), m[1])  # punta: base, filo y brillo
	draw_rect(Rect2(3.0, -1.0, 1.0, 0.5), m[3])
	draw_rect(Rect2(4.0, -0.5, 1.0, 1.0), m[2])
	draw_rect(Rect2(4.0, -0.5, 0.5, 0.5), m[4])
	draw_rect(Rect2(5.0, -0.5, 0.5, 0.5), m[3])
