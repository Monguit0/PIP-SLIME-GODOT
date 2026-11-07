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


func _ready() -> void:
	z_index = 3
	vel = Vector2(face * 205.0, -10.0)
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
	var p: Player = game.player if game != null else null
	if p != null and not p.dead and p.box().has_point(global_position + Vector2(face * 2.0, 0)):
		if p.hurt(global_position.x - face * 10.0):
			Fx.burst(get_parent(), global_position, 5, [Pal.W, Pal.L], 50.0, 20.0, 0.3)
			queue_free()
			return


func _draw() -> void:
	if stuck:
		# la punta quedó adentro: se ve el palo vibrando desde ahí
		var w := sin(life * 70.0) * 0.22 * wobble
		draw_set_transform(Vector2(TIP, 0), w, Vector2.ONE)
		draw_line(Vector2(-5 - TIP, 0), Vector2(0, 0), Color("6b5a3a"), 1.0)
		draw_rect(Rect2(-6 - TIP, -1, 2, 2), Pal.SS)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_line(Vector2(-5, 0), Vector2(3, 0), Color("6b5a3a"), 1.0)
	draw_rect(Rect2(3, -1, 2, 2), Pal.L)  # punta con brillo verde, como los ojos del esqueleto
	draw_rect(Rect2(-6, -1, 2, 2), Pal.SS)
