extends Node2D
## Etapa 1: un nivel de prueba (La Pradera) con Pip arquero y slimes verdes.
## El nivel se arma por código para que sea fácil de leer y cambiar.

const W := 256
const H := 144
const GROUND := 128
const LEVEL_W := 1024

const PlayerScript := preload("res://scripts/player.gd")
const SlimeScript := preload("res://scripts/slime.gd")
const HudScript := preload("res://scripts/hud.gd")
const BgScript := preload("res://scripts/background.gd")

# suelo: tramos [x, ancho] (los huecos son pozos)
const GROUND_SEGS := [[0, 400], [440, 300], [776, 248]]
# plataformas de un solo sentido: [x, y, ancho]
const PLATFORMS := [[120, 96, 64], [230, 78, 56], [330, 100, 48], [520, 92, 72], [640, 70, 48], [820, 96, 80]]
# slimes: [x, índice de plataforma o -1 para el suelo]
const SLIMES := [[180, -1], [300, -1], [150, 0], [560, -1], [550, 3], [690, -1], [850, 5], [930, -1]]

var player: Player
var hud
var slimes_left := 0
var won := false
var over_t := -1.0


func _ready() -> void:
	_setup_input()
	var bg := Node2D.new()
	bg.set_script(BgScript)
	bg.z_index = -10
	add_child(bg)
	_build_level()
	_spawn_player()
	_spawn_slimes()
	hud = HudScript.new()
	add_child(hud)
	hud.player = player
	hud.main = self


func _process(dt: float) -> void:
	if Input.is_action_just_pressed("reiniciar") or (over_t > 1.0 and Input.is_action_just_pressed("saltar")):
		get_tree().reload_current_scene()
	if over_t >= 0.0:
		over_t += dt
	# caerse a un pozo
	if player and not player.dead and player.global_position.y > H + 40:
		player.invuln = 0.0
		player.ghost_t = 0.0
		player.hurt(player.global_position.x, player.hearts)
	# look-ahead de la cámara hacia donde mira el héroe
	var cam := player.camera
	cam.position.x = lerpf(cam.position.x, player.face * 26.0, minf(1.0, dt * 3.0))


func _setup_input() -> void:
	var map := {
		"izquierda": [KEY_LEFT, KEY_A],
		"derecha": [KEY_RIGHT, KEY_D],
		"abajo": [KEY_DOWN, KEY_S],
		"arriba": [KEY_UP, KEY_W],
		"saltar": [KEY_SPACE, KEY_Z, KEY_K],
		"atacar": [KEY_X, KEY_J],
		"especial": [KEY_SHIFT, KEY_V, KEY_L],
		"reiniciar": [KEY_R],
	}
	var pads := {
		"izquierda": [JOY_BUTTON_DPAD_LEFT], "derecha": [JOY_BUTTON_DPAD_RIGHT],
		"abajo": [JOY_BUTTON_DPAD_DOWN], "arriba": [JOY_BUTTON_DPAD_UP],
		"saltar": [JOY_BUTTON_A], "atacar": [JOY_BUTTON_X], "especial": [JOY_BUTTON_B],
		"reiniciar": [JOY_BUTTON_START],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for k in map[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		for b in pads.get(action, []):
			var j := InputEventJoypadButton.new()
			j.button_index = b
			InputMap.action_add_event(action, j)
	# stick izquierdo
	var axes := {"izquierda": [JOY_AXIS_LEFT_X, -1.0], "derecha": [JOY_AXIS_LEFT_X, 1.0], "abajo": [JOY_AXIS_LEFT_Y, 1.0], "arriba": [JOY_AXIS_LEFT_Y, -1.0]}
	for action in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = axes[action][0]
		m.axis_value = axes[action][1]
		InputMap.action_add_event(action, m)


func _build_level() -> void:
	for seg in GROUND_SEGS:
		_solid(Rect2(seg[0], GROUND, seg[1], H - GROUND + 40), 1, Ground.KIND_GROUND)
	for p in PLATFORMS:
		_solid(Rect2(p[0], p[1], p[2], 6), 2, Ground.KIND_PLATFORM)
	# paredes invisibles en los bordes del nivel
	_solid(Rect2(-16, -200, 16, 400), 1, Ground.KIND_NONE)
	_solid(Rect2(LEVEL_W, -200, 16, 400), 1, Ground.KIND_NONE)


func _solid(r: Rect2, layer: int, kind: int) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 0
	b.set_collision_layer_value(layer, true)
	b.collision_mask = 0
	b.position = r.position
	var s := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	s.shape = rect
	s.position = r.size / 2.0
	s.one_way_collision = layer == 2
	b.add_child(s)
	if kind != Ground.KIND_NONE:
		var g := Ground.new()
		g.size = r.size
		g.kind = kind
		b.add_child(g)
	add_child(b)


func _spawn_player() -> void:
	player = PlayerScript.new()
	player.position = Vector2(40, GROUND)
	add_child(player)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = LEVEL_W
	cam.limit_top = 0
	cam.limit_bottom = H
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.drag_vertical_enabled = true
	cam.drag_top_margin = 0.6
	cam.drag_bottom_margin = 0.2
	player.add_child(cam)
	player.camera = cam
	player.died.connect(_on_player_died)


func _spawn_slimes() -> void:
	for s in SLIMES:
		var sl := SlimeScript.new()
		var x: float = s[0]
		if s[1] >= 0:
			var p: Array = PLATFORMS[s[1]]
			sl.position = Vector2(p[0] + p[2] / 2.0, p[1])
			sl.min_x = p[0] + 8
			sl.max_x = p[0] + p[2] - 8
		else:
			sl.position = Vector2(x, GROUND)
			for seg in GROUND_SEGS:
				if x >= seg[0] and x <= seg[0] + seg[1]:
					sl.min_x = seg[0] + 8
					sl.max_x = seg[0] + seg[1] - 8
		add_child(sl)
		sl.killed.connect(_on_slime_killed)
		slimes_left += 1


func _on_slime_killed() -> void:
	slimes_left -= 1
	if slimes_left <= 0 and not won:
		won = true
		over_t = 0.0


func _on_player_died() -> void:
	over_t = 0.0


## Dibujo del suelo y las plataformas (pasto y tierra, estilo de la Pradera).
class Ground extends Node2D:
	const KIND_NONE := 0
	const KIND_GROUND := 1
	const KIND_PLATFORM := 2
	var size := Vector2.ZERO
	var kind := KIND_GROUND

	func _draw() -> void:
		if kind == KIND_GROUND:
			draw_rect(Rect2(Vector2.ZERO, size), Color("6b4a2e"))
			for x in range(0, int(size.x), 8):
				for y in range(6, int(size.y), 8):
					if (x / 8 + y / 8) % 3 == 0:
						draw_rect(Rect2(x + 2, y + 2, 2, 2), Color("553a24"))
			draw_rect(Rect2(0, 0, size.x, 4), Color("5cb84a"))
			draw_rect(Rect2(0, 4, size.x, 1), Color("3f8a35"))
			for x in range(0, int(size.x), 5):
				if x % 3 != 0:
					draw_rect(Rect2(x, -1, 1, 1), Color("8ad86a"))
		else:
			draw_rect(Rect2(Vector2.ZERO, size), Color("8a6440"))
			draw_rect(Rect2(0, 0, size.x, 2), Color("5cb84a"))
			draw_rect(Rect2(0, size.y - 1, size.x, 1), Color("553a24"))
