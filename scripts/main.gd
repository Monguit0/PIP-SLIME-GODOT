extends Node2D
## Nivel 1 (El Reino) igual que en el juego web: Pradera, Ruinas y Murallas, cada una de 512 px,
## y al final el Salón del Trono. El portón de cada zona se abre cuando no queda ningún slime.
## Todo está en coordenadas "lógicas" de 256x144 como el original; la cámara hace zoom x2 y los
## sprites HD (slimes, Pip) se dibujan a la mitad, igual que los píxeles HD del remaster.

const W := 256
const H := 144
const GROUND := 128
const WW := 1792
const DOOR_TOP := 82

const PlayerScript := preload("res://scripts/player.gd")
const SlimeScript := preload("res://scripts/slime.gd")
const HudScript := preload("res://scripts/hud.gd")
const BgScript := preload("res://scripts/background.gd")

const ZONES := [
	{"start": 0, "end": 512, "name": "PRADERA", "green": 4, "red": 1},
	{"start": 512, "end": 1024, "name": "RUINAS", "green": 4, "red": 2},
	{"start": 1024, "end": 1536, "name": "MURALLAS", "green": 3, "red": 3},
	{"start": 1536, "end": 1792, "name": "SALÓN DEL TRONO", "boss": true},
]
# plataformas de un solo sentido, copiadas de PLATS del original (x, y, ancho; 8 de alto)
const PLATS := [
	[40, 96, 64], [136, 72, 48], [216, 96, 64], [300, 64, 48], [376, 88, 56], [448, 60, 40],
	[560, 96, 48], [632, 72, 48], [704, 48, 64], [792, 72, 48], [864, 96, 48], [930, 64, 56],
	[1064, 96, 64], [1150, 64, 48], [1220, 88, 40], [1280, 56, 56], [1360, 96, 48], [1430, 72, 56],
	[1556, 96, 36], [1632, 66, 64], [1736, 96, 36],
]
const TORCHES := [[1100, 104], [1250, 104], [1400, 104], [1572, 70], [1756, 70]]

var player: Player
var camera: Camera2D
var cam_x := 0.0
var hud
var z := 0
var cleared := false
var won := false
var over_t := -1.0
var t := 0.0
var gates: Array = []  # cada uno: {x, open, want, door: StaticBody2D, node}
var banner := {"text": "", "sub": "", "t": 99.0}


func _ready() -> void:
	_setup_input()
	var bg := BgScript.new()
	bg.main = self
	add_child(bg)
	_build_level()
	_spawn_player()
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()
	hud = HudScript.new()
	hud.player = player
	hud.main = self
	add_child(hud)
	_enter_zone(0, true)


func _process(dt: float) -> void:
	t += dt
	banner.t += dt
	if Input.is_action_just_pressed("reiniciar") or (over_t > 1.0 and Input.is_action_just_pressed("saltar")):
		get_tree().reload_current_scene()
		return
	if over_t >= 0.0:
		over_t += dt
	_check_zone()
	_update_gates(dt)
	_update_camera(dt)


func _physics_process(_dt: float) -> void:
	# en el salón del trono todavía no hay jefe: llegar ahí es ganar (por ahora)
	if not won and z == 3:
		won = true
		over_t = 0.0
		_show_banner("¡LLEGASTE!", "EL MEGA CABALLERO LLEGA EN LA PRÓXIMA ETAPA")


# ---------------------------------------------------------------- zonas y portones

func _enter_zone(n: int, first: bool) -> void:
	z = n
	cleared = false
	if not first:
		gates[n - 1].want = 0.0  # el portón de atrás se cierra
		if player.hearts < player.max_hearts:
			player.hearts += 1
			player.hearts_changed.emit()
			Fx.popup(self, player.global_position + Vector2(0, -20), "+1 VIDA", Pal.R)
	if ZONES[n].get("boss", false):
		_show_banner("ZONA %d" % (n + 1), ZONES[n].name)
		return
	_spawn_slimes(n)
	_show_banner("ZONA %d" % (n + 1), ZONES[n].name)


func _check_zone() -> void:
	if z < 3 and not cleared and _alive_in_zone(z) == 0:
		cleared = true
		gates[z].want = 1.0
		_show_banner("¡PASO LIBRE!", "")
		Fx.shake(1.0, 0.9)
	if z < 3 and cleared and player.global_position.x > gates[z].x + 12:
		_enter_zone(z + 1, false)


func _alive_in_zone(n: int) -> int:
	var c := 0
	for s in get_tree().get_nodes_in_group("enemigos"):
		if not s.dead and s.zone == n:
			c += 1
	return c


func _update_gates(dt: float) -> void:
	for g in gates:
		var before: float = g.open
		if g.want > g.open:
			g.open = minf(g.want, g.open + dt * 1.1)
		elif g.want < g.open:
			g.open = maxf(g.want, g.open - dt * 7.0)
			if g.open == 0.0 and before > 0.0:
				Fx.shake(3.0, 0.2)
				Fx.burst(self, Vector2(g.x + 4, GROUND), 10, [Pal.SS, Pal.S, Pal.D], 60.0, 30.0, 0.5)
		# se puede pasar por abajo del arco cuando el portón subió casi todo
		var door: CollisionShape2D = g.door
		door.set_deferred("disabled", g.open >= 0.85)
		g.node.open = g.open
		g.node.blink = z < 3 and gates[z] == g and cleared and g.open < 1.0


func _spawn_slimes(n: int) -> void:
	var zd: Dictionary = ZONES[n]
	var kinds: Array = []
	for i in zd.green:
		kinds.append("green")
	for i in zd.red:
		kinds.append("red")
	var plats := PLATS.filter(func(p): return p[0] >= zd.start and p[0] < zd.end)
	var ground := [zd.start + 10, GROUND, zd.end - zd.start - 20]
	var made := 0
	var tries := 0
	while made < kinds.size() and tries < 200:
		tries += 1
		var surf: Array = ground if randf() < 0.45 or plats.is_empty() else plats[randi() % plats.size()]
		var x: float = surf[0] + 4 + randf() * (surf[2] - 18)
		if absf(x - player.global_position.x) < 90.0:
			continue
		var s := SlimeScript.new()
		s.kind = kinds[made]
		s.zone = n
		s.position = Vector2(x + 5, surf[1])
		if s.kind == "red":
			s.min_x = zd.start + 11
			s.max_x = zd.end - 11
		else:
			s.min_x = surf[0] + 6
			s.max_x = surf[0] + surf[2] - 6
		add_child(s)
		made += 1


# ---------------------------------------------------------------- cámara

func _update_camera(dt: float) -> void:
	var min_x: float = ZONES[z].start
	var max_x: float = ZONES[z].end - W
	# recién pasado el portón la cámara sigue atrás: no la empujamos de golpe
	if z < 3 and cam_x < min_x:
		min_x = cam_x
	if z < 3 and gates[z].open > 0.5:
		max_x = ZONES[z + 1].end - W
	if z == 3:
		min_x = ZONES[3].start
		max_x = min_x
	var look := player.face * 26.0
	var target := clampf(player.global_position.x - W / 2.0 + look, min_x, max_x)
	var before := cam_x
	cam_x += (target - cam_x) * minf(1.0, dt * (3.0 if z == 3 else 5.0))
	cam_x = minf(cam_x, maxf(max_x, before))
	camera.position = Vector2(roundf(cam_x * 2.0) / 2.0, 0)


func _show_banner(text: String, sub: String) -> void:
	banner = {"text": text, "sub": sub, "t": 0.0}


func _on_player_died() -> void:
	over_t = 0.0


# ---------------------------------------------------------------- armado del nivel

func _build_level() -> void:
	# el dibujo del nivel es la imagen original (suelo y plataformas)
	var arena := Sprite2D.new()
	arena.texture = preload("res://assets/level1/arena.png")
	arena.centered = false
	arena.scale = Vector2(0.5, 0.5)
	arena.position = Vector2(ZONES[3].start, 0)
	arena.z_index = -5
	add_child(arena)
	var art := Sprite2D.new()
	art.texture = preload("res://assets/level1/level.png")
	art.centered = false
	art.scale = Vector2(0.5, 0.5)
	art.z_index = -4
	add_child(art)
	var torches := Torches.new()
	torches.list = TORCHES
	torches.z_index = -3
	add_child(torches)

	_solid(Rect2(0, GROUND, WW, H - GROUND + 40), 1)
	for p in PLATS:
		_solid(Rect2(p[0], p[1], p[2], 8), 2)
	_solid(Rect2(-16, -300, 16, 600), 1)
	_solid(Rect2(WW, -300, 16, 600), 1)
	for i in 3:
		var gx: float = ZONES[i].end - 4
		_solid(Rect2(gx, -300, 8, 300 + DOOR_TOP), 1)  # el muro de arriba del arco
		var door_body := _solid(Rect2(gx, DOOR_TOP, 8, GROUND - DOOR_TOP), 1)
		var node := GateArt.new()
		node.position = Vector2(gx, 0)
		add_child(node)
		gates.append({"x": gx, "open": 0.0, "want": 0.0, "door": door_body.get_child(0), "node": node})


func _solid(r: Rect2, layer: int) -> StaticBody2D:
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
	add_child(b)
	return b


func _spawn_player() -> void:
	player = PlayerScript.new()
	player.position = Vector2(44, GROUND)
	add_child(player)
	player.died.connect(_on_player_died)


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
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.3)
		for k in map[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		for b in pads.get(action, []):
			var j := InputEventJoypadButton.new()
			j.button_index = b
			InputMap.action_add_event(action, j)
	var axes := {"izquierda": [JOY_AXIS_LEFT_X, -1.0], "derecha": [JOY_AXIS_LEFT_X, 1.0], "abajo": [JOY_AXIS_LEFT_Y, 1.0], "arriba": [JOY_AXIS_LEFT_Y, -1.0]}
	for action in axes:
		var already := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion:
				already = true
		if already:
			continue
		var m := InputEventJoypadMotion.new()
		m.axis = axes[action][0]
		m.axis_value = axes[action][1]
		InputMap.action_add_event(action, m)


## Portón: tres barrotes que suben, travesaños y el muro de piedra arriba del arco (como el original).
class GateArt extends Node2D:
	var open := 0.0
	var blink := false

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var lift := roundf(open * 44.0)
		var top := 82.0 - lift
		var bar_h := 128.0 - 82.0
		for i in 3:
			draw_rect(Rect2(i * 3, top, 2, bar_h), Pal.K)
			draw_rect(Rect2(i * 3, top, 1, bar_h), Pal.SS)
			draw_rect(Rect2(i * 3, top, 0.5, bar_h), Pal.S)
		var yy := 82.0 + 4 - lift
		while yy < 128.0 - lift:
			draw_rect(Rect2(-1, yy, 10, 2), Pal.D)
			yy += 8
		for i in 3:
			draw_rect(Rect2(i * 3, 128 - lift - 1, 1, 1), Pal.S)
		draw_rect(Rect2(-2, 0, 12, 82), Pal.K)
		var y2 := 0
		while y2 < 82:
			draw_rect(Rect2(-1 + ((y2 / 6) % 2) * 2, y2 + 1, 8, 4), Pal.SS)
			y2 += 6
		draw_rect(Rect2(-2, 80, 12, 2), Pal.S)
		if blink and int(Time.get_ticks_msec() / 1000.0 * 6.0) % 2 == 1:
			draw_rect(Rect2(-2, 80, 12, 1), Pal.Y)


## Antorchas de las murallas y el salón: brillo y llama de tres cuadros.
class Torches extends Node2D:
	var list: Array = []

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var tt := Time.get_ticks_msec() / 1000.0
		for p in list:
			var x: float = p[0]
			var y: float = p[1]
			var fl := int(tt * 12.0 + x) % 3
			draw_circle(Vector2(x + 0.5, y - 4), 15 + fl * 0.5, Color(0.16, 0.05, 0.0, 0.35))
			draw_circle(Vector2(x + 0.5, y - 4), 8 + fl * 0.5, Color(0.23, 0.09, 0.0, 0.45))
			draw_rect(Rect2(x - 1, y - 3, 3, 2), Pal.R)
			draw_rect(Rect2(x - 1 + (1 if fl == 1 else 0), y - 5, 2, 2), Pal.O)
			draw_rect(Rect2(x + (-1 if fl == 2 else 0), y - 6 - (1 if fl == 0 else 0), 1, 2), Pal.Y)
