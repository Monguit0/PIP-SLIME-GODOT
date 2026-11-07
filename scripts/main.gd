extends Node2D
## Nivel 1 (El Reino) igual que en el juego web: Pradera, Ruinas y Murallas, cada una de 512 px,
## y al final el Salón del Trono con el Mega Caballero. El portón de cada zona se abre cuando no queda
## ningún slime. Todo está en coordenadas "lógicas" de 256x144 como el original; la cámara hace zoom x2
## y los sprites HD (slimes, Pip, el jefe) se dibujan a la mitad, igual que los píxeles HD del remaster.
##
## Acá vive la partida: estado (título, juego, fin, victoria), puntos, combo, monedas, experiencia,
## cartas, flechas que caen, el jefe y el director de la música.

const W := 256
const H := 144
const GROUND := 128
const WW := 1792
const DOOR_TOP := 82
const XP_EVO := 130
const BEST_FILE := "user://record.txt"

const PlayerScript := preload("res://scripts/player.gd")
const SlimeScript := preload("res://scripts/slime.gd")
const SkelScript := preload("res://scripts/skeleton.gd")
const HudScript := preload("res://scripts/hud.gd")
const BgScript := preload("res://scripts/background.gd")
const CoinScript := preload("res://scripts/coin.gd")
const HazardScript := preload("res://scripts/hazard.gd")
const BossScript := preload("res://scripts/boss.gd")

const ZONES := [
	{"start": 0, "end": 512, "name": "PRADERA", "green": 4, "red": 1, "arch": 0, "axe": 1, "haz": 0.55},
	{"start": 512, "end": 1024, "name": "RUINAS", "green": 3, "red": 2, "arch": 2, "axe": 1, "haz": 0.85},
	{"start": 1024, "end": 1536, "name": "MURALLAS", "green": 2, "red": 2, "arch": 2, "axe": 2, "haz": 1.15},
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
## las cartas del arquero (HERO_CARDS del original)
const CARDS := [
	{"id": "vida", "name": "CORAZÓN EXTRA", "desc": "MÁS VIDA MÁXIMA", "col": "r"},
	{"id": "dmg", "name": "ARCO REFORZADO", "desc": "+1 DE DAÑO EN CADA GOLPE", "col": "o"},
	{"id": "cura", "name": "POCIÓN DE EMERGENCIA", "desc": "TE CURA A MITAD DE VIDA, 1 VEZ POR ZONA", "col": "l"},
	{"id": "energia", "name": "CRISTAL DE MANÁ", "desc": "ENERGÍA 60% MÁS RÁPIDA", "col": "c"},
	{"id": "veloz", "name": "BOTAS LIGERAS", "desc": "CORRÉS 15% MÁS RÁPIDO", "col": "y"},
	{"id": "carga", "name": "CONCENTRACIÓN", "desc": "CARGÁS EL DOBLE DE RÁPIDO", "col": "p"},
	{"id": "triple", "name": "FLECHA TRIPLE", "desc": "EL FLECHAZO SALE DE A TRES", "col": "c", "only": true},
	{"id": "fantasma", "name": "PASO FANTASMA", "desc": "EL DASH CUESTA LA MITAD", "col": "b", "only": true},
]
const SCALE := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16]  # combo de monedas: escala mayor

## al reiniciar desde el fin del juego se saltea el título
static var skip_title := false

var player: Player
var camera: Camera2D
var cam_x := 0.0
var hud
var z := 0
var cleared := false
var t := 0.0
var gates: Array = []  # cada uno: {x, open, want, door: CollisionShape2D, node}
var banner := {"text": "", "sub": "", "t": 99.0, "long": false, "card": false}

var state := "title"        # title, play, over, win
var end_t := 0.0
var score := 0
var shown_score := 0.0
var score_bump := 0.0
var best := 0
var combo := 0
var combo_t := 0.0
var xp := 0
var xp_bump := 0.0
var cards: Array = []
var pick = null             # elección de cartas: {ids, sel, t, done, done_t}
var haz_t := 4.0
var boss = null             # boss.gd
var fade := 0.0


func _ready() -> void:
	add_to_group("juego")
	get_tree().paused = false
	Fx.reset()
	_setup_input()
	best = _load_best()
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
	if skip_title:
		skip_title = false
		start_game()
		fade = 0.9


func start_game() -> void:
	if state == "play":
		return
	state = "play"
	Snd.play("oleada", {"rate": 1.2, "vol": 0.7, "vary": false})
	_enter_zone(0, true)


func _process(dt: float) -> void:
	t += dt
	banner.t += dt
	var real := dt / maxf(Engine.time_scale, 0.001)
	fade = maxf(0.0, fade - real)
	shown_score += (score - shown_score) * minf(1.0, real * 12.0)
	if absf(score - shown_score) < 0.5:
		shown_score = score
	score_bump = maxf(0.0, score_bump - real * 4.0)
	xp_bump = maxf(0.0, xp_bump - real * 2.0)
	if state == "over" or state == "win":
		end_t += dt
	if Input.is_action_just_pressed("reiniciar") and state != "title":
		restart()
		return
	if (state == "over" and end_t > 1.2) or (state == "win" and end_t > 3.2):
		if Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("atacar"):
			restart()
			return
	_check_zone()
	_update_gates(dt)
	_update_camera(dt)


func _physics_process(dt: float) -> void:
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	if state == "play" and z < 3:
		_hazards(dt)


func restart() -> void:
	skip_title = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- puntos, monedas y experiencia

func add_score(pts: int) -> void:
	score += pts
	score_bump = 1.0


func collect_coin(c: Node2D) -> void:
	combo = combo + 1 if combo_t > 0.0 else 1
	combo_t = 1.3
	var pts := 10 * combo
	add_score(pts)
	var semi: int = SCALE[mini(combo, SCALE.size()) - 1]
	Snd.play("moneda", {"rate": pow(2.0, semi / 12.0), "vary": false})
	Fx.burst(self, c.global_position, 8, [Pal.Y, Pal.W, Pal.O], 55.0, 30.0, 0.45, 160.0)
	Fx.popup(self, c.global_position + Vector2(0, -6), "+%d" % pts, Pal.C if combo > 1 else Pal.Y)
	gain_xp(1)


## Lo llaman los slimes y los esqueletos al morir.
func slime_killed(s: Node2D, how: String, crit: bool) -> void:
	var kind: String = s.get("kind")
	var extra: int = {"red": 10, "skarch": 20, "skaxe": 25}.get(kind, 0)
	var base := 10 if how == "trap" else (25 if how == "stomp" else 15) + extra
	var pts := base * (2 if crit else 1)
	add_score(pts)
	var top := s.global_position + Vector2(0, -20 if kind.begins_with("sk") else -7)
	Fx.popup(self, top + Vector2(0, -12 if crit else -4), "+%d" % pts, Pal.Y if crit else Pal.L)
	var exp_pts: int = {"red": 5, "skarch": 7, "skaxe": 8}.get(kind, 4)
	gain_xp(exp_pts, top + Vector2(0, -4))


func gain_xp(n: int, at = null) -> void:
	if state != "play" or n <= 0 or player.evo:
		return
	xp = mini(XP_EVO, xp + n)
	xp_bump = 1.0
	if at != null:
		Fx.popup(self, at + Vector2(0, -10), "+%d EXP" % n, Pal.C)
	if xp >= XP_EVO:
		player.evolve()
		_show_banner("¡EVOLUCIÓN!", "AHORA SOS CAZADOR", true, true)


func boss_defeated(at: Vector2) -> void:
	add_score(1000)
	Fx.popup(self, at, "+1000", Pal.Y)
	Snd.play("oleada", {"delay": 0.6, "vary": false})
	Snd.play("oleada", {"delay": 1.1, "rate": 1.26, "vary": false})
	state = "win"
	end_t = 0.0
	_show_banner("¡VICTORIA!", "EL MEGA CABALLERO CAYÓ", true)
	_save_best()


func _on_player_died() -> void:
	state = "over"
	end_t = 0.0
	combo = 0
	Snd.play("derrota", {"delay": 0.12, "vary": false})
	_save_best()


func _load_best() -> int:
	if not FileAccess.file_exists(BEST_FILE):
		return 0
	var f := FileAccess.open(BEST_FILE, FileAccess.READ)
	return int(f.get_as_text()) if f else 0


func _save_best() -> void:
	if score <= best:
		return
	best = score
	var f := FileAccess.open(BEST_FILE, FileAccess.WRITE)
	if f:
		f.store_string(str(score))


# ---------------------------------------------------------------- cartas

func has_card(id: String) -> bool:
	return cards.has(id)


func card_of(id: String) -> Dictionary:
	for c in CARDS:
		if c.id == id:
			return c
	return {}


## Reparte tres cartas que todavía no tenga y congela el juego hasta que elija.
func start_pick() -> void:
	var pool := CARDS.filter(func(c): return not cards.has(c.id))
	pool.shuffle()
	var ids: Array = []
	for c in pool.slice(0, 3):
		ids.append(c.id)
	if ids.is_empty():
		return
	pick = {"ids": ids, "sel": mini(1, ids.size() - 1), "t": 0.0, "done": false, "done_t": 0.0}
	get_tree().paused = true
	Snd.play("posesion", {"rate": 1.3, "vary": false})


## La llama el HUD (que sigue andando con el juego en pausa) cuando ya se vio la carta elegida.
func finish_pick() -> void:
	if pick == null:
		return
	var id: String = pick.ids[pick.sel]
	pick = null
	get_tree().paused = false
	cards.append(id)
	if id == "vida":
		player.max_hearts += 1
		player.hearts = mini(player.max_hearts, player.hearts + 1)
		player.hearts_changed.emit()
	Fx.popup(self, player.global_position + Vector2(0, -26), card_of(id).name, Pal.Y)
	banner.t = 0.0
	Snd.play("oleada", {"rate": 1.4, "vol": 0.6, "vary": false})


# ---------------------------------------------------------------- música

## Qué ánimo de la canción va según lo que pasa (moodNow del original).
func music_director() -> void:
	var danger := player.max_hearts > 1 and player.hearts == 1 and not player.dead
	var m := "z%d" % mini(2, z)
	if state == "title":
		m = "titulo"
		danger = false
	elif state == "over":
		m = "derrota"
		danger = false
	elif state == "win":
		m = "victoria"
		danger = false
	elif pick != null:
		m = "cartas"
	elif boss != null and is_instance_valid(boss) and boss.state != "gone":
		if boss.state == "dying":
			m = "victoria"
		elif boss.state in ["wait", "drop", "roar"]:
			m = "intro"
		elif boss.phase >= 3:
			m = "final"
		elif boss.phase >= 2 or boss.state == "rage":
			m = "furia"
		else:
			m = "jefe"
	Snd.mood(m, danger)


# ---------------------------------------------------------------- zonas y portones

func _enter_zone(n: int, first: bool) -> void:
	z = n
	cleared = false
	player.cure_used = false
	if not first:
		gates[n - 1].want = 0.0  # el portón de atrás se cierra
		if player.hearts < player.max_hearts:
			player.hearts += 1
			player.hearts_changed.emit()
			Fx.popup(self, player.global_position + Vector2(0, -20), "+1 VIDA", Pal.R)
		for c in get_tree().get_nodes_in_group("monedas"):
			c.queue_free()
		for h in get_tree().get_nodes_in_group("peligros"):
			h.queue_free()
	if ZONES[n].get("boss", false):
		_start_boss()
		return
	_spawn_coins(n)
	_spawn_slimes(n)
	_show_banner("ZONA %d" % (n + 1), ZONES[n].name)
	haz_t = 3.0 + randf() * 2.0
	if first:
		start_pick()


func _check_zone() -> void:
	if state != "play":
		return
	if z < 3 and not cleared and _alive_in_zone(z) == 0:
		cleared = true
		gates[z].want = 1.0
		_show_banner("¡PASO LIBRE!", "")
		Snd.play("porton", {"vary": false})
		Fx.shake(1.0, 0.9)
	if z < 3 and cleared and player.global_position.x > gates[z].x + 12:
		_enter_zone(z + 1, false)


func alive_in_zone(n: int) -> int:
	return _alive_in_zone(n)


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
				Snd.play("metal", {"rate": 0.6, "vol": 0.8, "vary": false})
				Fx.burst(self, Vector2(g.x + 4, GROUND), 10, [Pal.SS, Pal.S, Pal.D], 60.0, 30.0, 0.5)
		# se puede pasar por abajo del arco cuando el portón subió casi todo
		var door: CollisionShape2D = g.door
		door.set_deferred("disabled", g.open >= 0.85)
		g.node.open = g.open
		g.node.blink = z < 3 and gates[z] == g and cleared and g.open < 1.0


func _spawn_coins(n: int) -> void:
	var spots: Array = []
	for p in PLATS:
		if p[0] >= ZONES[n].start and p[0] < ZONES[n].end:
			var x: float = p[0] + 8
			while x <= p[0] + p[2] - 8:
				spots.append(Vector2(x, p[1] - 10))
				x += 16
	var gx: float = ZONES[n].start + 40
	while gx < ZONES[n].end - 30:
		spots.append(Vector2(gx, GROUND - 10))
		gx += 44
	spots.shuffle()
	for i in mini(8, spots.size()):
		var c := CoinScript.new()
		c.game = self
		c.position = spots[i]
		c.born = -i * 0.06
		add_child(c)


func _spawn_slimes(n: int) -> void:
	var zd: Dictionary = ZONES[n]
	var kinds: Array = []
	for i in zd.green:
		kinds.append("green")
	for i in zd.red:
		kinds.append("red")
	for i in zd.get("arch", 0):
		kinds.append("skarch")
	for i in zd.get("axe", 0):
		kinds.append("skaxe")
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
		var kind: String = kinds[made]
		var s: Node2D
		if kind.begins_with("sk"):
			s = SkelScript.new()
		else:
			s = SlimeScript.new()
		s.set("kind", kind)
		s.set("zone", n)
		s.position = Vector2(x + 5, surf[1])
		if kind == "red" or (kind.begins_with("sk") and surf == ground):
			s.set("min_x", float(zd.start + 11))
			s.set("max_x", float(zd.end - 11))
		else:
			s.set("min_x", float(surf[0] + 6))
			s.set("max_x", float(surf[0] + surf[2] - 6))
		add_child(s)
		made += 1


## El primer techo que hay debajo de x (donde se clava lo que cae).
func landing_y(x: float) -> float:
	var best_y := float(GROUND)
	for p in PLATS:
		if x >= p[0] + 1 and x <= p[0] + p[2] - 1 and p[1] < best_y:
			best_y = p[1]
	return best_y


func spawn_hazard(x: float, delay: float = 0.0, big: bool = false, warn: float = 1.1) -> Node2D:
	var h := HazardScript.new()
	h.game = self
	h.setup(x, landing_y(x), delay, big, warn)
	h.add_to_group("peligros")
	add_child(h)
	return h


## Flechas que caen del cielo cada tanto, más seguido en cada zona (y de a tres en las murallas).
func _hazards(dt: float) -> void:
	if pick != null:
		return
	haz_t -= dt
	if haz_t > 0.0:
		return
	var zd: Dictionary = ZONES[z]
	haz_t = (3.6 + randf() * 2.0) / zd.haz
	var lo := maxf(cam_x + 10.0, zd.start + 10.0)
	var hi := minf(cam_x + W - 10.0, zd.end - 10.0)
	var x := player.global_position.x + randf_range(-20, 20) if randf() < 0.65 else lo + randf() * (hi - lo)
	x = roundf(clampf(x, lo, hi))
	spawn_hazard(x)
	if z == 2 and randf() < 0.45:
		spawn_hazard(roundf(maxf(lo, x - 26)), 0.25)
		spawn_hazard(roundf(minf(hi, x + 26)), 0.5)


func _start_boss() -> void:
	boss = BossScript.new()
	boss.game = self
	boss.player = player
	add_child(boss)
	banner = {"text": "", "sub": "", "t": 99.0, "long": false, "card": false}


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
	var base := Vector2(roundf(cam_x * 2.0) / 2.0, 0)
	# acercamiento del crítico: el punto del golpe queda quieto en la pantalla
	var zc := 1.0
	if Fx.zoom_t > 0.0:
		var f := Fx.zoom_t / 0.55
		zc = 1.0 + 0.24 * f * f
	camera.zoom = Vector2(2.0 * zc, 2.0 * zc)
	camera.position = Fx.zoom_at - (Fx.zoom_at - base) / zc if zc > 1.0 else base


func _show_banner(text: String, sub: String, long: bool = false, card: bool = false) -> void:
	banner = {"text": text, "sub": sub, "t": 0.0, "long": long, "card": card}


func show_banner(text: String, sub: String, long: bool = false, card: bool = false) -> void:
	_show_banner(text, sub, long, card)


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
		door_body.set_meta("gate_art", node)  # las flechas clavadas en el portón suben con él
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
	player.game = self
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
		"poder": [KEY_C, KEY_E, KEY_I],
		"reiniciar": [KEY_R],
	}
	var pads := {
		"izquierda": [JOY_BUTTON_DPAD_LEFT], "derecha": [JOY_BUTTON_DPAD_RIGHT],
		"abajo": [JOY_BUTTON_DPAD_DOWN], "arriba": [JOY_BUTTON_DPAD_UP],
		"saltar": [JOY_BUTTON_A], "atacar": [JOY_BUTTON_X], "especial": [JOY_BUTTON_B],
		"poder": [JOY_BUTTON_Y], "reiniciar": [JOY_BUTTON_BACK],
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
