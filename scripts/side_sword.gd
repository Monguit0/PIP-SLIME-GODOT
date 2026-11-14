extends Node2D
## Espada que cruza la pantalla de costado: el castigo por no cruzar el portón a tiempo (ver _cross_clock en
## main.gd). Primero un aviso que titila en el borde, a su altura; después pasa volando de lado a lado.
## No se rompe, no se frena con el escudo y atraviesa las plataformas: solo se esquiva (saltándola o agachando
## la altura: bajando o subiendo de plataforma).

const SWORD := preload("res://assets/sprites/items/sword_down.png")
const SPEED := 210.0

var game
var dir := 1.0
var warn := 0.7
var unstoppable := true
var flown := 0.0
var t := 0.0
# para el bot, que la mira como a una flecha
var face := 1.0
var stuck := false
var hero := false


func _ready() -> void:
	z_index = 4
	add_to_group("espadas_lado")
	face = dir
	Snd.play("alerta", {"rate": 1.3, "vol": 0.5, "vary": false})


func _physics_process(dt: float) -> void:
	t += dt
	queue_redraw()
	if warn > 0.0:
		warn -= dt
		if warn <= 0.0:
			Snd.play("tajo", {"rate": 1.4, "vol": 0.5})
		return
	position.x += dir * SPEED * dt
	flown += SPEED * dt
	Fx.part(get_parent(), position - Vector2(dir * 5.0, 0), Vector2.ZERO, 0.0, 0.14, Pal.R if int(t * 30.0) % 2 == 0 else Pal.O)
	var b := Rect2(position.x - 5.5, position.y - 2.0, 11, 4)
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p != null and not p.dead and p.box().intersects(b):
			p.hurt(position.x - dir * 8.0, 1, self)
	if flown > 600.0:
		queue_free()


func _draw() -> void:
	if warn > 0.0:
		# el aviso: un cartelito rojo que titila cada vez más rápido y la línea por donde va a pasar
		var k := 1.0 - warn / 0.7
		if int(t * (8.0 + 20.0 * k)) % 2 == 0:
			var x := dir * 7.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - dir * 3.0, -3.5), Vector2(x - dir * 3.0, 3.5), Vector2(x + dir * 2.0, 0)]), Pal.R)
			draw_rect(Rect2(x - dir * 3.0 - (1.0 if dir > 0 else 0.0), -1, 1, 2), Pal.Y)
		var a := 0.15 + 0.25 * k
		for i in 12:
			draw_rect(Rect2(dir * (12.0 + i * 9.0) - 1.5, -0.25, 3, 0.5), Color(Pal.R, a))
		return
	# la espada, acostada con la punta hacia donde va (el dibujo original apunta para abajo)
	draw_set_transform(Vector2.ZERO, -PI / 2.0 * dir, Vector2.ONE)
	draw_texture_rect(SWORD, Rect2(-2.5, -5.5, 5, 11), false, Color(1.0, 0.55, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
