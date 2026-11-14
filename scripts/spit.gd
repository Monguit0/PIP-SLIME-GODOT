extends Node2D
## Baba que escupen los slimes en el modo Villano (lob y updateShots del original): sale en arco, le saca 1
## al héroe que toca y se aplasta contra el piso o una plataforma. La del slime rojo es naranja.
## El espadazo de un héroe la rompe (player.gd, _slash_clear) y el escudo la frena.

const Pix := preload("res://scripts/pix.gd")
const GRAV := 420.0
const GROUND := 128.0

var vel := Vector2.ZERO
var red := false
var by_player := false   # la tiró el slime que maneja el villano
var game                 # main.gd
var src                  # el slime que la escupió
var t := 0.0
var done := false
var spin := 0.0


func _ready() -> void:
	z_index = 3
	add_to_group("babas")


func cols() -> Array:
	return [Pal.RAMP_O[4], Pal.O, Pal.R] if red else [Pal.RAMP_L[4], Pal.L, Pal.G]


func _physics_process(dt: float) -> void:
	if done:
		return
	t += dt
	var py := global_position.y
	vel.y += GRAV * dt
	position += vel * dt
	queue_redraw()
	if randf() < 0.6:
		Fx.part(get_parent(), global_position + Vector2(randf_range(-1, 1), randf_range(-1, 1)), Vector2.ZERO, 60.0, 0.2, cols()[1 + randi() % 2])
	# héroes
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p == null or p.dead:
			continue
		var d := global_position - p.global_position
		if absf(d.x) <= 6.0 and d.y >= -19.0 and d.y <= 1.0:
			p.hurt(global_position.x - signf(vel.x) * 4.0, 1, self)
			splat()
			return
	# piso y plataformas (solo bajando, como todo lo que cae)
	if vel.y > 0.0:
		if global_position.y >= GROUND:
			global_position.y = GROUND - 1.0
			splat(true)
			return
		if game != null:
			for pl in game.PLATS:
				if py <= pl[1] + 1.0 and global_position.y >= pl[1] and global_position.x >= pl[0] and global_position.x <= pl[0] + pl[2]:
					global_position.y = pl[1] - 1.0
					splat(true)
					return
	if game != null:
		var zd: Dictionary = game.ZONES[game.z]
		if global_position.x < zd.start + 2.0 or global_position.x > zd.end - 2.0:
			splat()
			return
	if t > 4.0 or global_position.y > GROUND + 20.0:
		queue_free()


## el escudo del caballero la frenó
func blocked(_dir: float) -> void:
	pass


func splat(on_floor: bool = false) -> void:
	if done:
		return
	done = true
	var c := cols()
	Snd.play("baba", {"rate": 1.3, "vol": 0.5})
	Fx.goo(get_parent(), global_position, 6, c[1], 70.0, global_position.y + (0.0 if on_floor else 20.0))
	Fx.burst(get_parent(), global_position, 5, c, 60.0, 30.0, 0.3, 200.0)
	if on_floor:
		Fx.splat(get_parent(), global_position + Vector2(0, 1), c[1], 6.0)
	queue_free()


## una gota que se estira según la velocidad, con brillo
func _draw() -> void:
	var c := cols()
	var dir := vel.normalized() if vel.length() > 1.0 else Vector2.DOWN
	Pix.disc(self, -dir * 2.5, 1.0, c[2])
	Pix.disc(self, -dir * 1.2, 1.5, c[2])
	Pix.disc(self, Vector2.ZERO, 2.5, c[1])
	Pix.disc(self, dir * 0.5 + Vector2(-0.5, -0.5), 1.0, c[0])
