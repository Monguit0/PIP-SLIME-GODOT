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
const BotScript := preload("res://scripts/hero_bot.gd")
## modo Villano: los bichos que defienden cada zona (INVADE_MOBS del original) y en cuál entrás primero.
const VILLAIN_MOBS := [
	["green", "green", "red", "green", "green"],
	["green", "skarch", "skaxe", "red", "skarch"],
	["skaxe", "skarch", "red", "skaxe", "skarch", "green"],
]
const VILLAIN_FIRST := ["green", "skarch", "skaxe"]
## Refuerzos: bichos que van llegando de a uno cuando cae alguno. No están en el original: acá los héroes
## limpian una zona muy rápido y sin ellos la defensa dura un suspiro.
const VILLAIN_RESERVE := [
	["green", "red", "green", "green", "red", "green"],
	["skarch", "green", "skaxe", "red"],
	["skaxe", "skarch", "red", "skarch"],
]
const MODES := ["campaign", "villano", "multi"]
## Multijugador local: los lugares de la sala. El que nadie elige lo maneja un bot.
const SEATS := ["v", "archer", "knight", "barb", "mage"]
const CAM_Z_MIN := 0.5   # lo más lejos que se va la cámara: la zona entera (dos pantallas)
const CAM_PAD := 30.0
const CROSS_TIME := 10.0  # segundos para cruzar el portón de una zona limpia, antes de que lluevan espadas
const SIDE_TIME := 20.0   # y a los 20, además, espadas que cruzan de costado
const SideSword := preload("res://scripts/side_sword.gd")

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
const TORCHES := [[1100, 104], [1250, 104], [1400, 104]]
# antorchas pintadas en el salón del trono (centro de la llama): ahí solo titila la punta y salen chispas
const HALL_TORCHES := [[1556.5, 62.5], [1586.5, 70.5], [1741.5, 72.0], [1770.0, 63.0]]
## las cartas de los héroes (HERO_CARDS del original): "only" es el héroe que la puede sacar
const CARDS := [
	{"id": "vida", "name": "CORAZÓN EXTRA", "desc": "MÁS VIDA MÁXIMA", "col": "r"},
	{"id": "dmg", "name": {"archer": "ARCO REFORZADO", "knight": "ESPADA AFILADA", "barb": "HACHA PESADA", "mage": "BASTÓN RÚNICO"}, "desc": "+1 DE DAÑO EN CADA GOLPE", "col": "o"},
	{"id": "cura", "name": "POCIÓN DE EMERGENCIA", "desc": "TE CURA A MITAD DE VIDA, 1 VEZ POR ZONA", "col": "l"},
	{"id": "energia", "name": "CRISTAL DE MANÁ", "desc": "ENERGÍA 60% MÁS RÁPIDA", "col": "c"},
	{"id": "veloz", "name": "BOTAS LIGERAS", "desc": "CORRÉS 15% MÁS RÁPIDO", "col": "y"},
	{"id": "carga", "name": "CONCENTRACIÓN", "desc": "CARGÁS EL DOBLE DE RÁPIDO", "col": "p"},
	{"id": "triple", "name": "FLECHA TRIPLE", "desc": "EL FLECHAZO SALE DE A TRES", "col": "c", "only": "archer"},
	{"id": "fantasma", "name": "PASO FANTASMA", "desc": "EL DASH CUESTA LA MITAD", "col": "b", "only": "archer"},
	{"id": "muralla", "name": "ESCUDO LIVIANO", "desc": "EL ESCUDO GASTA LA MITAD", "col": "b", "only": "knight"},
	{"id": "ira", "name": "SANGRE CALIENTE", "desc": "LA FURIA DURA EL DOBLE", "col": "r", "only": "barb"},
	{"id": "remolino", "name": "REMOLINO", "desc": "EL GIRO PEGA TRES VECES", "col": "o", "only": "barb"},
	{"id": "inferno", "name": "GRAN BOLA", "desc": "LA EXPLOSIÓN ES MUCHO MÁS GRANDE", "col": "o", "only": "mage"},
	{"id": "brasas", "name": "BRASAS ETERNAS", "desc": "LA QUEMADURA DURA EL DOBLE", "col": "r", "only": "mage"},
]
const SCALE := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16]  # combo de monedas: escala mayor

## al reiniciar desde el fin del juego se saltea el título
static var skip_title := false
## al reiniciar (a la partida o al título) la pantalla entra desde negro
static var fade_in := false
## el héroe elegido en el título (queda para la próxima partida)
static var kind := "archer"
## "campaign": sos el héroe. "villano": manejás a los bichos, de a uno, contra los cuatro héroes (bots).
static var mode := "campaign"
## multijugador local: es el modo Villano, pero cada lugar lo puede manejar una persona (seats: lugar -> dispositivo)
static var multi := false
static var seats := {}
static var lobby_done := false

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
# modo Villano
var heroes: Array = []      # los cuatro héroes que maneja el juego
var ctrl = null             # el bicho que manejás ahora
var possess_t := 0.0        # cuenta hasta entrar en otro cuerpo
var soul = null             # el alma viajando: {from, to, t}
var soul_from = null
var last_ctrl_x := 60.0     # donde estaba tu último cuerpo (para la cámara mientras buscás otro)
var fallen := 0             # héroes que tumbaste
var dealt := 0              # corazones que les sacaste
var reserve: Array = []     # refuerzos que faltan llegar
var reinforce_t := 0.0
var vdev = null             # con qué se maneja al villano (null: cualquier control, un solo jugador)
var vbot := false           # multijugador sin nadie de villano: los bichos y el jefe se manejan solos
var lobby := false          # la sala del multijugador, sobre el título
var lobby_t := 0.0
var lobby_flash := {}
var cam_z := 1.0            # 1 = normal; menos = más lejos (multijugador)
var end_msg := ["", ""]
var cross_t := 0.0           # lo que queda para cruzar el portón
var late := false            # se acabó el tiempo: llueven espadas y no hay curación al cruzar
var rain_t := 0.0
var rain_n := 0
var side_t := 0.0
var side_n := 0
var zone_lost := false      # se quedó sin bichos: el portón se abre y los héroes avanzan
var fade := 0.0
var _warm_paths: Array = []  # cuadros del jefe y los esqueletos que se están cargando en segundo plano
var _warm: Array = []        # los ya cargados: quedan vivos para que load() los saque de la caché


func _ready() -> void:
	add_to_group("juego")
	get_tree().paused = false
	Fx.reset()
	_setup_input()
	Ctl.setup()
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
	Fx.warm(self, player.global_position + Vector2(0, -12))
	# primero los otros héroes (se pueden elegir ya en el título), después el jefe y los esqueletos
	_warm_paths = Player.asset_paths(player.kind) + BossScript.asset_paths() + SkelScript.asset_paths()
	for p in _warm_paths:
		ResourceLoader.load_threaded_request(p)
	hud = HudScript.new()
	hud.player = player
	hud.main = self
	add_child(hud)
	if skip_title:
		skip_title = false
		start_game()
	if fade_in:
		fade_in = false
		fade = 0.9


## En el título: arriba y abajo cambian de modo.
func mode_name() -> String:
	return "multi" if multi else mode


func pick_mode(step: int) -> void:
	var m: String = MODES[(MODES.find(mode_name()) + step + MODES.size()) % MODES.size()]
	multi = m == "multi"
	mode = "campaign" if m == "campaign" else "villano"
	Snd.play("menu", {"rate": 0.9 if mode == "villano" else 1.2, "vol": 0.6, "vary": false})
	if mode == "villano":
		Snd.play("posesion", {"rate": 1.5, "vol": 0.5, "vary": false})


## En el título: izquierda y derecha cambian de héroe (el que está parado en la pradera).
func pick_hero(step: int) -> void:
	var ks: Array = Player.KINDS
	kind = ks[(ks.find(kind) + step + ks.size()) % ks.size()]
	player.set_kind(kind)
	player.squash = Vector2(0.7, 1.35)
	Snd.play("menu", {"rate": 1.2, "vol": 0.6, "vary": false})
	Snd.play("salto", {"rate": 1.4, "vol": 0.4})
	var at := player.global_position + Vector2(0, -12)
	Fx.burst(self, at, 10, [Pal.W, Pal.Y, Pal.C], 60.0, 30.0, 0.35, 100.0)
	Fx.ring(self, at, Pal.W, 0.0, 14.0, 1.0, 0.25)
	Fx.dust(self, player.global_position, 4, 30.0, 4.0, 1.6)


func start_game() -> void:
	if state == "play" or lobby:
		return
	if multi and not lobby_done:
		# multijugador: primero la sala, para que cada uno elija lugar
		lobby = true
		lobby_t = 0.0
		Snd.play("menu", {"rate": 1.4, "vol": 0.6, "vary": false})
		return
	state = "play"
	Snd.play("oleada", {"rate": 1.2, "vol": 0.7, "vary": false})
	if mode == "villano":
		_start_villano()
		return
	_enter_zone(0, true)


# ---------------------------------------------------------------- multijugador local

func seat_of(dev) -> String:
	for s in seats:
		if seats[s] == dev:
			return s
	return ""


## La sala: cada control se suma con salto, se cambia de lugar con izquierda y derecha, sale con atrás,
## y START (o Enter) arranca. Los lugares vacíos quedan para los bots.
func lobby_step(dt: float) -> void:
	lobby_t += dt
	for s in lobby_flash.keys():
		lobby_flash[s] -= dt
	if lobby_t < 0.25:
		return
	for s in seats.keys():  # se desenchufó
		if not Ctl.devices().has(seats[s]):
			seats.erase(s)
	for d in Ctl.devices():
		var seat := seat_of(d)
		if seat == "":
			if Ctl.tap(d, "saltar") or Ctl.tap(d, "atacar"):
				for s in SEATS:
					if not seats.has(s):
						seats[s] = d
						lobby_flash[s] = 0.25
						Snd.play("moneda", {"rate": 1.0 + SEATS.find(s) * 0.08, "vary": false})
						break
			elif Ctl.tap(d, "back") or Ctl.tap(d, "especial"):
				lobby = false
				Snd.play("menu", {"rate": 0.8, "vol": 0.6, "vary": false})
				return
			continue
		var step := int(Ctl.tap(d, "derecha")) - int(Ctl.tap(d, "izquierda"))
		if step != 0:
			var i := SEATS.find(seat)
			for n in SEATS.size() - 1:
				i = (i + step + SEATS.size()) % SEATS.size()
				if not seats.has(SEATS[i]):
					seats.erase(seat)
					seats[SEATS[i]] = d
					lobby_flash[SEATS[i]] = 0.2
					Snd.play("menu", {"rate": 1.2, "vol": 0.5, "vary": false})
					break
		elif Ctl.tap(d, "back") or Ctl.tap(d, "especial"):
			seats.erase(seat)
			Snd.play("menu", {"rate": 0.8, "vol": 0.5, "vary": false})
		elif Ctl.tap(d, "start"):
			lobby = false
			lobby_done = true
			start_game()
			return
	if not seats.is_empty() and Ctl.tap(Ctl.KB, "start"):
		lobby = false
		lobby_done = true
		start_game()


## la flechita con el nombre del control sobre el héroe de cada persona
class HeroTag extends Node2D:
	var txt := ""
	var col := Color.WHITE
	var hero: Player

	func _ready() -> void:
		z_index = 20

	func _process(_dt: float) -> void:
		visible = hero != null and not hero.dead

	func _draw() -> void:
		PText.draw(self, txt, 0, -33, col, 1, 1)
		draw_colored_polygon(PackedVector2Array([Vector2(-1.5, -27.5), Vector2(1.5, -27.5), Vector2(0, -25.5)]), col)


# ---------------------------------------------------------------- modo Villano

## Arranca la partida de villano en la Pradera: los cuatro héroes entran por la izquierda manejados por bots,
## los slimes defienden la zona y vos entrás en el primero.
func _start_villano() -> void:
	z = 0
	cleared = false
	vdev = seats.get("v") if multi else null
	vbot = multi and not seats.has("v")
	var kinds: Array = Player.KINDS
	for i in kinds.size():
		var h: Player = player
		if i == 0:
			h.set_kind(kinds[0])
		else:
			h = PlayerScript.new()
			h.game = self
			h.kind = kinds[i]
			add_child(h)
		h.position = Vector2(18 + i * 13, GROUND)
		if multi and seats.has(kinds[i]):
			# lo maneja una persona, con su control
			h.pad = seats[kinds[i]]
			var tag := HeroTag.new()
			tag.hero = h
			tag.txt = Ctl.tag(h.pad)
			tag.col = Ctl.color(h.pad)
			h.add_child(tag)
		else:
			h.bot = true
			h.brain = BotScript.new()
			h.brain.game = self
		h.invuln = 0.6
		if i > 0:
			h.died.connect(_on_hero_died.bind(h))
		h.hurt_by.connect(_on_hero_hurt)
		heroes.append(h)
		Fx.dust(self, h.position, 3, 24.0, 4.0, 1.4)
	player.died.disconnect(_on_player_died)
	player.died.connect(_on_hero_died.bind(player))
	_villano_zone(0)


## Empieza la defensa de una zona: aparecen sus bichos y entrás en el primero.
func _villano_zone(n: int) -> void:
	z = n
	zone_lost = false
	late = false
	cleared = false
	_spawn_villain_mobs(n)
	reserve = VILLAIN_RESERVE[n].duplicate()
	reinforce_t = 3.0
	possess_t = 0.0
	if vbot:
		_show_banner("ZONA %d" % (n + 1), ZONES[n].name)
		return
	_possess_next(true)
	_show_banner("ZONA %d" % (n + 1), ZONES[n].name + " · SOS " + (ctrl.mob_name() if ctrl != null else "SLIME"))


## Los héroes cruzaron el portón (enterInvadeZone): se cierra atrás, los que llegaron recuperan 2 de vida y
## los esperan los bichos de la zona nueva. Después de las Murallas viene el Salón del Trono.
func _villano_next() -> void:
	var n := z + 1
	gates[z].want = 0.0
	for g in ["babas", "flechas_malas", "hechizos", "peligros", "espadas_lado"]:
		for o in get_tree().get_nodes_in_group(g):
			o.queue_free()
	if n >= VILLAIN_MOBS.size():
		_villano_throne()
		return
	for h in heroes:
		if late:
			# llegaron tarde: se quedan sin el premio
			if not h.dead and h.hearts < h.max_hearts:
				Fx.popup(self, h.global_position + Vector2(0, -24), "SIN CURA", Pal.S)
		elif not h.dead and h.hearts < h.max_hearts:
			h.hearts = mini(h.max_hearts, h.hearts + 2)
			h.hearts_changed.emit()
			Fx.popup(self, h.global_position + Vector2(0, -24), "+2", Pal.L)
	_villano_zone(n)


## Llegaron al trono: los héroes se curan del todo y ahora manejás al Mega Caballero.
func _villano_throne() -> void:
	z = 3
	zone_lost = false
	ctrl = null
	reserve = []
	for h in heroes:
		if not h.dead:
			if h.hearts < h.max_hearts:
				Fx.popup(self, h.global_position + Vector2(0, -24), "+%d" % (h.max_hearts - h.hearts), Pal.L)
			h.hearts = h.max_hearts
			h.hearts_changed.emit()
	boss = BossScript.new()
	boss.game = self
	boss.player = heroes[0]
	add_child(boss)
	if vbot:
		boss.make_villain()
	else:
		boss.make_ctrl()
	banner = {"text": "", "sub": "", "t": 99.0, "long": false, "card": false}


func _spawn_villain_mobs(n: int) -> void:
	var zd: Dictionary = ZONES[n]
	var plats := PLATS.filter(func(p): return p[0] >= zd.start + 90 and p[0] < zd.end)
	var ground := [zd.start + 120, GROUND, zd.end - zd.start - 140]
	var list: Array = VILLAIN_MOBS[n]
	for i in list.size():
		var k: String = list[i]
		var surf: Array = ground
		# en plataformas: casi siempre los slimes verdes, seguido los arqueros, cada tanto el resto
		var odds := 0.7 if k == "green" else (0.6 if k == "skarch" else 0.25)
		if not plats.is_empty() and randf() < odds:
			surf = plats[randi() % plats.size()]
		var s := _villain_mob(n, k, Vector2(surf[0] + 6 + randf() * maxf(1.0, surf[2] - 12), surf[1]), surf)
		s.spawn = 0.3 + i * 0.12


func _villain_mob(n: int, k: String, at: Vector2, surf: Array = []) -> Node2D:
	var zd: Dictionary = ZONES[n]
	var s: Node2D
	if k.begins_with("sk"):
		s = SkelScript.new()
	else:
		s = SlimeScript.new()
	s.kind = k
	s.zone = n
	s.villain = true
	s.position = at
	s.min_x = float(zd.start + 6)
	s.max_x = float(gates[n].x - 6)
	# el esqueleto que apareció en una plataforma la patrulla sin caerse (hasta que entres en él)
	if k.begins_with("sk") and not surf.is_empty() and surf[1] < GROUND:
		s.min_x = float(surf[0] + 6)
		s.max_x = float(surf[0] + surf[2] - 6)
	add_child(s)
	return s


## Llega un refuerzo: cae desde arriba del muro del portón, con aviso.
func _reinforce() -> void:
	var k: String = reserve.pop_front()
	# donde más lejos quede de los héroes, para que no lo reciban a los golpes
	var zd: Dictionary = ZONES[z]
	var at := Vector2(gates[z].x - 20.0, GROUND)
	var best := -1.0
	for i in 8:
		var x: float = zd.start + 30.0 + (gates[z].x - 50.0 - zd.start) * i / 7.0
		var near := 1e9
		for h in heroes:
			if not h.dead:
				near = minf(near, absf(h.global_position.x - x))
		if near > best:
			best = near
			at.x = x + randf_range(-8, 8)
	var s := _villain_mob(z, k, at + Vector2(0, -60))
	s.spawn = 0.25
	s.pdir = -1.0
	Snd.play("alerta", {"rate": 1.2, "vol": 0.5})
	Fx.popup(self, at + Vector2(0, -22), "¡REFUERZO!", Pal.O if k == "red" else Pal.L)
	Fx.ring(self, at + Vector2(0, -4), Pal.W, 0.0, 12.0, 0.4, 0.3)


## Tu alma entra en otro bicho: al empezar, un slime común; después, el que esté más cerca de los héroes.
func _possess_next(first: bool) -> void:
	var alive: Array = []
	for m in get_tree().get_nodes_in_group("enemigos"):
		if not m.dead and m.zone == z and m.get("villain") == true:
			alive.append(m)
	if alive.is_empty():
		ctrl = null
		return
	var bx := 0.0
	var nb := 0
	for h in heroes:
		if not h.dead:
			bx += h.global_position.x
			nb += 1
	bx = bx / nb if nb > 0 else 0.0
	var host = alive[0]
	if first:
		for m in alive:
			if m.kind == VILLAIN_FIRST[mini(z, VILLAIN_FIRST.size() - 1)]:
				host = m
				break
	else:
		alive.sort_custom(func(a, b): return absf(a.global_position.x - bx) < absf(b.global_position.x - bx))
		host = alive[0]
	for m in alive:
		m.ctrl = false
	ctrl = host
	host.possess()
	if soul_from != null:
		soul = {"from": soul_from, "to": host, "t": 0.0}
	soul_from = null
	Snd.play("posesion", {"vary": false})
	if not first:
		_show_banner("AHORA SOS", host.mob_name())


func _villano_step(dt: float) -> void:
	if ctrl != null and is_instance_valid(ctrl) and not ctrl.dead:
		last_ctrl_x = ctrl.global_position.x
	if soul != null:
		# el alma: chispas celestes que van en arco del cuerpo que perdiste al nuevo
		soul.t += dt
		var k := clampf(soul.t / 0.6, 0.0, 1.0)
		if is_instance_valid(soul.to):
			var to: Vector2 = soul.to.global_position + Vector2(0, -6)
			var at: Vector2 = soul.from.lerp(to, k) + Vector2(0, -sin(k * PI) * 30.0)
			for i in 2:
				Fx.part(self, at + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)), Vector2(0, -10), 0.0, 0.3, Pal.C if randf() < 0.5 else Pal.W)
			last_ctrl_x = at.x
		if soul.t > 0.6:
			soul = null
	if state != "play":
		return
	if z >= 3:
		# el Salón del Trono: ganás si caen los cuatro (si cae el jefe, avisa él: boss_defeated)
		for h in heroes:
			if not h.dead:
				return
		_villano_end(true)
		return
	var field := _alive_in_zone(z)
	if not reserve.is_empty() and field < VILLAIN_MOBS[z].size():
		reinforce_t -= dt * (3.0 if field == 0 else 1.0)
		if reinforce_t <= 0.0:
			reinforce_t = 2.6
			_reinforce()
			field += 1
	if vbot:
		ctrl = null
	elif ctrl == null or not is_instance_valid(ctrl) or ctrl.dead:
		ctrl = null
		possess_t -= dt
		if possess_t <= 0.0 and field > 0:
			_possess_next(false)
	if zone_lost:
		_cross_clock(dt)
	var up := 0
	var crossed := true
	var first: Player = null   # el primero que cruzó el portón
	for h in heroes:
		if not h.dead:
			up += 1
			if h.global_position.x < gates[z].x + 20.0:
				crossed = false
			elif first == null:
				first = h
	if multi and zone_lost and first != null and not crossed and gates[z].open > 0.85:
		# multijugador: cuando cruza uno, cruzan todos (los demás aparecen a su lado)
		var i := 0
		for h in heroes:
			if h.dead or h.global_position.x >= gates[z].x + 20.0:
				continue
			Fx.dust(self, h.global_position, 4, 30.0, 4.0, 1.6)
			h.global_position = Vector2(gates[z].x + 24.0 + i * 9.0, GROUND)
			h.velocity = Vector2.ZERO
			h.invuln = maxf(h.invuln, 0.6)
			h.squash = Vector2(0.7, 1.35)
			Fx.ring(self, h.global_position + Vector2(0, -10), Pal.C, 0.0, 14.0, 1.0, 0.3)
			Fx.burst(self, h.global_position + Vector2(0, -10), 8, [Pal.C, Pal.W], 60.0, 30.0, 0.4, 0.0)
			i += 1
		Snd.play("posesion", {"rate": 1.3, "vol": 0.6, "vary": false})
		crossed = true
	if up == 0:
		_villano_end(true)
	elif field == 0 and reserve.is_empty():
		if not zone_lost:
			# te quedaste sin bichos en esta zona: se abre el portón y los héroes siguen
			zone_lost = true
			cross_t = CROSS_TIME
			late = false
			gates[z].want = 1.0
			_show_banner("ZONA PERDIDA", "LOS HÉROES AVANZAN")
			Snd.play("porton", {"vary": false})
			Fx.shake(1.0, 0.9)
		elif gates[z].open > 0.85 and crossed:
			_villano_next()


## Zona limpia: hay CROSS_TIME segundos para cruzar el portón. Pasado ese tiempo llueven espadas, cada vez
## más y con menos aviso, una sobre cada héroe que no cruzó y otras al azar. Atraviesan las plataformas (caen
## hasta el piso), así que no hay dónde ponerse a resguardo; y al cruzar ya no hay curación.
func _cross_clock(dt: float) -> void:
	var was := ceili(cross_t)
	cross_t -= dt
	if not late:
		if cross_t <= 0.0:
			late = true
			rain_t = 0.35
			rain_n = 0
			side_t = 0.0
			side_n = 0
			_show_banner("¡SE ACABÓ EL TIEMPO!", "LLUEVEN ESPADAS · SIN CURACIÓN")
			Snd.play("rugido", {"rate": 1.3, "vol": 0.6, "vary": false})
			Fx.shake(3.0, 0.4)
		elif ceili(cross_t) != was and cross_t <= 3.0:
			Snd.play("alerta", {"rate": 1.0 + (3.0 - cross_t) * 0.12, "vol": 0.6, "vary": false})
		return
	var gx: float = gates[z].x
	if cross_t <= CROSS_TIME - SIDE_TIME:
		# a los 20 segundos: espadas de costado, de los dos lados, a la altura de alguno de los que faltan
		if side_n == 0 and side_t <= 0.0:
			_show_banner("¡ESPADAS POR TODOS LADOS!", "CRUCEN YA")
		side_t -= dt
		if side_t <= 0.0:
			var left: Array = heroes.filter(func(h): return not h.dead and h.global_position.x < gx + 20.0)
			var sy := GROUND - 7.0
			if not left.is_empty() and randf() < 0.7:
				sy = left[randi() % left.size()].global_position.y - 7.0
			var s := SideSword.new()
			s.game = self
			s.dir = 1.0 if side_n % 2 == 0 else -1.0
			var vw := W / cam_z
			s.position = Vector2(cam_x + 2.0 if s.dir > 0.0 else cam_x + vw - 2.0, sy)
			add_child(s)
			side_n += 1
			side_t = maxf(0.45, 1.3 - side_n * 0.07)
	rain_t -= dt
	if rain_t > 0.0:
		return
	var warn := maxf(0.45, 0.75 - rain_n * 0.03)
	var n := 0
	for h in heroes:
		if not h.dead and h.global_position.x < gx + 20.0:
			_rain_sword(h.global_position.x + randf_range(-3.0, 3.0), n * 0.04, warn)
			n += 1
	var lo := maxf(ZONES[z].start + 6.0, cam_x)
	for i in mini(12, 3 + rain_n):
		_rain_sword(randf_range(lo, gx + 14.0), n * 0.04, warn)
		n += 1
	rain_n += 1
	rain_t = maxf(0.4, 1.0 - rain_n * 0.06)


func _rain_sword(x: float, delay: float, warn: float) -> void:
	var s := spawn_hazard(x, delay, true, warn)
	s.land_y = GROUND  # atraviesa las plataformas: ni arriba ni abajo de una hay resguardo
	s.unstoppable = true


func _villano_end(_won: bool) -> void:
	end_t = 0.0
	if multi:
		# cayeron los cuatro: ganó el villano (si era una persona, festeja; si no, perdieron todos)
		state = "over" if vbot else "win"
		end_msg = ["GANÓ EL VILLANO", "LOS HÉROES NO LLEGARON" if z < 3 else "EL TRONO SIGUE EN PIE"]
		_show_banner("¡CAYERON LOS HÉROES!", "", true)
		Snd.play("derrota" if vbot else "oleada", {"vary": false})
		return
	state = "win"
	add_score(500)
	_show_banner("¡DEFENDISTE EL TRONO!" if z >= 3 else "¡DETUVISTE A LOS HÉROES!", "+500", true)
	Snd.play("oleada", {"vary": false})
	Snd.play("oleada", {"delay": 0.5, "rate": 1.26, "vary": false})


func _on_hero_hurt(_src) -> void:
	dealt += 1
	add_score(20)


func _on_hero_died(h: Player) -> void:
	fallen += 1
	add_score(150)
	var hname: String = Player.HEROES[h.kind].name
	Fx.popup(self, h.global_position + Vector2(0, -28), "¡CAYÓ EL " + hname + "!", Pal.Y, true)
	Fx.hitstop(0.12)
	Fx.shake(4.0, 0.3)
	Snd.play("critico", {"rate": 0.8, "vary": false})
	Snd.play("oleada", {"rate": 1.5, "vol": 0.6, "delay": 0.1, "vary": false})


func _process(dt: float) -> void:
	t += dt
	banner.t += dt
	var real := dt / maxf(Engine.time_scale, 0.001)
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
			restart(true)
			return
	if mode == "villano":
		_villano_step(dt)
	else:
		_check_zone()
	_update_gates(dt)
	_update_camera(dt)
	if not _warm_paths.is_empty():
		_collect_warm()


## Junta los cuadros que ya terminaron de cargar en segundo plano (unos pocos por cuadro).
func _collect_warm() -> void:
	var got := 0
	var i := _warm_paths.size() - 1
	while i >= 0 and got < 32:
		var p: String = _warm_paths[i]
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_warm.append(ResourceLoader.load_threaded_get(p))
			_warm_paths.remove_at(i)
			got += 1
		elif st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_warm_paths.remove_at(i)
		i -= 1


func _physics_process(dt: float) -> void:
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	if state == "play" and z < 3 and mode != "villano":
		_hazards(dt)


## Vuelve a empezar. Desde el fin del juego (to_title) vuelve al título para elegir otro héroe;
## con R arranca directo con el mismo.
func restart(to_title: bool = false) -> void:
	skip_title = not to_title
	if to_title:
		lobby_done = false  # la revancha (R) arranca con los mismos lugares; desde el título se vuelve a la sala
	fade_in = true
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
	Fx.twinkle(self, c.global_position, Pal.Y, 5.0 + minf(combo, 6) * 0.5, 0.3)
	Fx.ring(self, c.global_position, Pal.Y if combo <= 1 else Pal.C, 0.0, 9.0 + minf(combo, 6), 1.0, 0.25)
	Fx.burst(self, c.global_position, 6, [Pal.Y, Pal.W, Pal.O], 60.0, 30.0, 0.4, 160.0)
	Fx.popup(self, c.global_position + Vector2(0, -6), "+%d" % pts, Pal.C if combo > 1 else Pal.Y, combo >= 5)
	gain_xp(1)


## Lo llaman los slimes y los esqueletos al morir.
func slime_killed(s: Node2D, how: String, crit: bool) -> void:
	if mode == "villano":
		# era el tuyo: tu alma queda suelta un momento y entra en otro
		if s == ctrl:
			ctrl = null
			possess_t = 1.1
			soul_from = s.global_position + Vector2(0, -6)
			Fx.flash_red = 0.2
		return
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
	if state != "play" or n <= 0 or player.evo or mode == "villano":
		return
	xp = mini(XP_EVO, xp + n)
	xp_bump = 1.0
	if at != null:
		Fx.popup(self, at + Vector2(0, -10), "+%d EXP" % n, Pal.C)
	if xp >= XP_EVO:
		player.evolve()
		_show_banner("¡EVOLUCIÓN!", "AHORA SOS " + Player.HEROES[player.kind].evo, true, true)


func boss_defeated(at: Vector2) -> void:
	if multi:
		var humans := seats.size() - (0 if vbot else 1)
		state = "win" if humans > 0 else "over"
		end_t = 0.0
		end_msg = ["¡GANARON LOS HÉROES!", "CAYÓ EL MEGA CABALLERO"]
		_show_banner("¡CAYÓ EL TRONO!", "GANARON LOS HÉROES", true)
		Snd.play("oleada" if humans > 0 else "derrota", {"delay": 0.6, "vary": false})
		return
	if mode == "villano":
		# eras vos: los héroes se quedan con el trono
		state = "over"
		end_t = 0.0
		_show_banner("CAYÓ EL TRONO", "LOS HÉROES GANARON", true)
		Snd.play("derrota", {"delay": 0.6, "vary": false})
		return
	add_score(1000)
	Fx.popup(self, at, "+1000", Pal.Y, true)
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


## el nombre de la carta para el héroe que juega (la de daño cambia según el arma)
func card_name(c: Dictionary) -> String:
	return c.name[player.kind] if c.name is Dictionary else c.name


## Reparte tres cartas que todavía no tenga (las propias de otro héroe no salen) y congela el juego hasta que elija.
func start_pick() -> void:
	var pool := CARDS.filter(func(c): return not cards.has(c.id) and c.get("only", player.kind) == player.kind)
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
	Fx.popup(self, player.global_position + Vector2(0, -26), card_name(card_of(id)), Pal.Y)
	banner.t = 0.0
	Snd.play("oleada", {"rate": 1.4, "vol": 0.6, "vary": false})


# ---------------------------------------------------------------- música

## Qué ánimo de la canción va según lo que pasa (moodNow del original).
func music_director() -> void:
	var danger := player.max_hearts > 1 and player.hearts == 1 and not player.dead
	if mode == "villano":  # en peligro cuando te queda un solo cuerpo
		danger = state == "play" and _alive_in_zone(z) + reserve.size() == 1
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
				Fx.burst(self, Vector2(g.x + 4, GROUND), 8, [Pal.SS, Pal.S, Pal.D], 60.0, 30.0, 0.5)
				Fx.dust(self, Vector2(g.x + 4, GROUND), 6, 40.0, 4.0, 2.4)
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
	# multijugador: si las personas se separan, la cámara se aleja (hasta ver la zona entera) apoyada en el
	# piso, y se vuelve a acercar cuando se juntan. Se aleja rápido y se acerca despacio.
	var xs: Array = []
	var solo: Player = null
	if multi and state == "play" and z < 3:
		for h in heroes:
			if not h.dead and not h.bot:
				xs.append(h.global_position.x)
				solo = h
		# el villano cuenta mientras tenga bichos (también en el rato que su alma busca otro cuerpo)
		if not vbot and not zone_lost and not xs.is_empty():
			xs.append(last_ctrl_x)
	# la correa: con la cámara ya lo más lejos posible, el que se sigue alejando espera a los demás
	# (si no, la cámara arrastraría al que quedó atrás)
	var hs: Array = heroes.filter(func(h): return not h.dead and not h.bot) if not xs.is_empty() else []
	if hs.size() > 1:
		var lo := 1e9
		var hi := -1e9
		for h in hs:
			lo = minf(lo, h.global_position.x)
			hi = maxf(hi, h.global_position.x)
		var limit := W / CAM_Z_MIN - CAM_PAD * 2.0
		if hi - lo > limit:
			for h in hs:
				if h.global_position.x == hi and h.velocity.x > 0.0:
					h.global_position.x = lo + limit
				elif h.global_position.x == lo and h.velocity.x < 0.0:
					h.global_position.x = hi - limit
			xs = xs.map(func(v): return clampf(v, lo, lo + limit))
	var tz := 1.0
	if xs.size() > 1:
		tz = clampf(W / (float(xs.max()) - float(xs.min()) + CAM_PAD * 2.0), CAM_Z_MIN, 1.0)
	if absf(tz - cam_z) > 0.004:
		cam_z += (tz - cam_z) * minf(1.0, dt * (6.0 if tz < cam_z else 1.6))
	if cam_z > 0.995 and tz == 1.0:
		cam_z = 1.0
	var vw := W / cam_z
	var min_x: float = ZONES[z].start
	var max_x: float = ZONES[z].end - vw
	# recién pasado el portón la cámara sigue atrás: no la empujamos de golpe
	if z < 3 and cam_x < min_x:
		min_x = cam_x
	if z < 3 and gates[z].open > 0.5:
		max_x = ZONES[z + 1].end - vw
	if z == 3:
		min_x = minf(ZONES[3].start, WW - vw)
		max_x = min_x
	max_x = maxf(min_x, max_x)
	var look := player.face * 26.0
	var focus := player.global_position.x
	if mode == "villano" and state != "title":
		# la cámara sigue al bicho que manejás (o al alma, mientras busca otro cuerpo)
		focus = last_ctrl_x
		look = ctrl.face * 26.0 if ctrl != null and is_instance_valid(ctrl) else 0.0
		if zone_lost or z >= 3:
			# sin bichos: la cámara acompaña a los héroes (al que va adelante) hasta la zona que sigue
			var lead := -1e9
			for h in heroes:
				if not h.dead:
					lead = maxf(lead, h.global_position.x)
			if lead > -1e8:
				focus = lead
				look = 20.0
		if ctrl != null and is_instance_valid(ctrl) and ctrl.charging:
			# cargando la baba: la cámara se corre para que entren el slime y el lugar donde va a caer
			focus = clampf((ctrl.global_position.x + ctrl.aim_x) / 2.0, ctrl.global_position.x - 104.0, ctrl.global_position.x + 104.0)
			look = 0.0
	if xs.size() > 1:
		focus = (float(xs.min()) + float(xs.max())) / 2.0
		look = 0.0
	elif xs.size() == 1:
		focus = solo.global_position.x
		look = solo.face * 26.0
	elif multi and vbot and state != "title" and z < 3:
		if true:
			# no queda ninguna persona en pie: acompaña a los bots
			var sum := 0.0
			var n := 0
			for h in heroes:
				if not h.dead:
					sum += h.global_position.x
					n += 1
			if n > 0:
				focus = sum / n
				look = 0.0
	var target := clampf(focus - vw / 2.0 + look, min_x, max_x)
	var before := cam_x
	cam_x += (target - cam_x) * minf(1.0, dt * (3.0 if z == 3 else (9.0 if cam_z < 0.999 else 5.0)))
	cam_x = minf(cam_x, maxf(max_x, before))
	if multi and state == "play" and z < 3:
		# nadie se va de la pantalla: con la cámara ya lo más lejos posible, el borde frena
		for h in heroes:
			if not h.dead and not h.bot:
				h.global_position.x = clampf(h.global_position.x, cam_x + 5.0, cam_x + vw - 5.0)
	var base := Vector2(roundf(cam_x * 2.0) / 2.0, H * (1.0 - 1.0 / cam_z))
	# acercamiento del crítico: el punto del golpe queda quieto en la pantalla
	var zc := 1.0
	if Fx.zoom_t > 0.0:
		var f := Fx.zoom_t / 0.55
		zc = 1.0 + 0.24 * f * f
	camera.zoom = Vector2(2.0 * zc * cam_z, 2.0 * zc * cam_z)
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
	torches.hall = HALL_TORCHES
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
	player.kind = kind
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
		"poder": [JOY_BUTTON_Y],  # (reiniciar queda solo en la R del teclado: en un joystick se apretaba sin querer)
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
	var hall: Array = []

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
		for p in hall:
			var x: float = p[0]
			var y: float = p[1]
			var fl := int(tt * 10.0 + x) % 3
			# la punta de la llama pintada cambia de forma (medio píxel, como el arte HD)
			draw_rect(Rect2(x - 0.5 + (0.5 if fl == 1 else 0.0) - (0.5 if fl == 2 else 0.0), y - 3.5 - (0.5 if fl == 0 else 0.0), 0.5, 1.0), Pal.Y)
			draw_rect(Rect2(x, y - 2.5, 0.5, 0.5), Pal.RAMP_Y[3] if fl == 2 else Pal.O)
			# chispas que suben y se apagan
			for k in 2:
				var ph := fposmod(tt * 0.9 + x * 0.37 + k * 0.5, 1.0)
				var c: Color = Pal.Y if ph < 0.35 else (Pal.O if ph < 0.7 else Pal.R)
				var sx := roundf((x + sin(ph * 7.0 + k * 2.0 + x) * 1.5) * 2.0) / 2.0
				draw_rect(Rect2(sx, roundf((y - 4.0 - ph * 9.0) * 2.0) / 2.0, 0.5, 0.5), c)
