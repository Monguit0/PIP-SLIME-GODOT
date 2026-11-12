extends CanvasLayer
## Todo lo que va arriba del juego, con la fuente del original (PText) y en coordenadas de 256x144:
## corazones, energía, experiencia, puntos y combo, zona y slimes que quedan, barra del jefe,
## franjas de cine, pantalla roja, cuadro de impacto, ¡CRÍTICO!, carteles, elección de cartas,
## título, fin del juego y victoria. Sigue andando con el juego en pausa (para elegir cartas).

const Pix := preload("res://scripts/pix.gd")
const W := 256.0
const H := 144.0
const HEART := preload("res://assets/sprites/items/heart.png")
const HEART0 := preload("res://assets/sprites/items/heart0.png")
const SLIMES := preload("res://assets/sprites/slimes.png")
const COIN := preload("res://assets/sprites/items/coin.png")
const COIN_SPIN := preload("res://assets/sprites/items/coin_spin.png")
const UI := "res://assets/sprites/ui/"
const BAR_EN := preload("res://assets/sprites/ui/bar_energia.png")
const BAR_XP := preload("res://assets/sprites/ui/bar_exp.png")
const BAR_BOSS := preload("res://assets/sprites/ui/bar_jefe.png")
const ICON_EN := preload("res://assets/sprites/ui/icon_energia.png")
const ICON_XP := preload("res://assets/sprites/ui/icon_exp.png")
const ICON_BOSS := preload("res://assets/sprites/ui/icon_jefe.png")
const CARD := preload("res://assets/sprites/ui/carta.png")
const CARD_GLOW := preload("res://assets/sprites/ui/carta_brillo.png")
## barras: dónde va el relleno (en 256x144) y dónde empieza ese relleno dentro de su marco HD
const EN := Rect2(12, 14.5, 34, 3)
const XPB := Rect2(12, 24.5, 34, 2)
const BOSS := Rect2(68, 12, 120, 4)
const CARD_W := 80.0
const CARD_H := 98.0
const RAMPS := {"r": Pal.RAMP_R, "o": Pal.RAMP_O, "l": Pal.RAMP_L, "c": Pal.RAMP_C, "y": Pal.RAMP_Y,
	"p": Pal.RAMP_P, "b": Pal.RAMP_B, "g": Pal.RAMP_G, "s": Pal.RAMP_S}

var player: Player
var main  # main.gd
var canvas: Control
var t := 0.0
var cine := 0.0
var icons := {}


func _ready() -> void:
	layer = 10
	scale = Vector2(2, 2)
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = Control.new()
	canvas.size = Vector2(W, H)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)
	# el dibujo de cada carta; la de daño tiene uno por arma (carta_dmg_knight.png, carta_dmg_barb.png)
	for c in main.CARDS:
		for path in [UI + "carta_%s.png" % c.id, "res://assets/sprites/items/card_%s.png" % c.id]:
			if ResourceLoader.exists(path):
				icons[c.id] = load(path)
				break
		for k in Player.KINDS:
			var kp := UI + "carta_%s_%s.png" % [c.id, k]
			if ResourceLoader.exists(kp):
				icons[c.id + "_" + k] = load(kp)


func _process(dt: float) -> void:
	var real := dt / maxf(Engine.time_scale, 0.001)
	t += real
	# la entrada en negro al reiniciar se aclara acá: el HUD sigue andando con el juego en pausa
	# (al reiniciar se reparten las cartas enseguida y el juego queda en pausa hasta elegir)
	main.fade = maxf(0.0, main.fade - real)
	var b = main.boss
	var on: bool = b != null and is_instance_valid(b) and b.state in ["wait", "drop", "roar", "dying"]
	cine += ((1.0 if on else 0.0) - cine) * minf(1.0, real * 5.0)
	main.music_director()
	if main.state == "title" and t > 0.3:
		if Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("atacar"):
			main.start_game()
		elif Input.is_action_just_pressed("izquierda"):
			main.pick_hero(-1)
		elif Input.is_action_just_pressed("derecha"):
			main.pick_hero(1)
	if main.pick != null:
		_pick_input(real)
	canvas.queue_redraw()


# ---------------------------------------------------------------- elección de cartas

func _pick_input(real: float) -> void:
	var pk: Dictionary = main.pick
	pk.t += real
	if pk.done:
		pk.done_t += real
		if pk.done_t > 0.45:
			main.finish_pick()
		return
	if pk.t < 0.25:
		return
	var n: int = pk.ids.size()
	if Input.is_action_just_pressed("izquierda"):
		pk.sel = (pk.sel + n - 1) % n
		Snd.play("menu", {"rate": 1.2, "vol": 0.5, "vary": false})
	elif Input.is_action_just_pressed("derecha"):
		pk.sel = (pk.sel + 1) % n
		Snd.play("menu", {"rate": 1.2, "vol": 0.5, "vary": false})
	if Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("atacar"):
		pk.done = true
		Snd.play("moneda", {"rate": 0.8, "vary": false})


# ---------------------------------------------------------------- dibujo

func _text(s: String, x: float, y: float, c: Color, sc: int = 1, align: int = 1, shadow: Color = Color(0, 0, 0, 1), ramp: Array = []) -> void:
	PText.draw(canvas, s, x, y, c, sc, align, shadow, ramp)


func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	canvas.draw_rect(Rect2(x, y, w, h), c)


## de coordenadas del mundo a la pantalla de 256x144 (con zoom y temblor incluidos)
func _screen(p: Vector2) -> Vector2:
	return (get_viewport().get_canvas_transform() * p) / 2.0


func _draw_hud() -> void:
	if player == null:
		return
	if main.state == "title":
		_draw_title()
		return
	_draw_overlays()
	_draw_status()
	_draw_banner()
	if main.pick != null:
		_draw_picker()
	if main.state == "over":
		_draw_over()
	elif main.state == "win" and main.end_t > 2.6:
		_draw_win()
	if main.fade > 0.0:
		_rect(0, 0, W, H, Color(0.04, 0.03, 0.06, minf(1.0, main.fade / 0.9)))


func _draw_overlays() -> void:
	# franjas de cine cuando entra o cae el jefe
	if cine > 0.01:
		var hb := roundf(cine * 15.0)
		_rect(0, 0, W, hb, Pal.K)
		_rect(0, H - hb, W, hb, Pal.K)
	if Fx.flash_red > 0.0:
		_rect(0, 0, W, H, Color(0.69, 0.24, 0.33, minf(1.0, Fx.flash_red / 0.18) * 0.35))
	# cuadro de impacto: un instante en blanco y negro con rayos que salen del golpe
	if Fx.impact_t > 0.0:
		var inv := Fx.impact_t < 0.045
		var c := _screen(Fx.impact_at)
		_rect(0, 0, W, H, Pal.K if inv else Pal.W)
		var ray := Pal.W if inv else Pal.K
		for i in 26:
			var a := (i / 26.0) * TAU + sin(i * 7.1 + Fx.impact_seed) * 0.12
			var wd := 0.03 + (i % 3) * 0.012
			var r0 := 12.0 + (i % 4) * 5.0
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a), sin(a)) * r0,
				c + Vector2(cos(a - wd), sin(a - wd)) * 320.0, c + Vector2(cos(a + wd), sin(a + wd)) * 320.0]), ray)
		canvas.draw_circle(c, 6.0, ray)
	# ¡CRÍTICO!
	if Fx.crit_text_t >= 0.0:
		var ct := Fx.crit_text_t
		if not (ct > 0.8 and int(ct * 20.0) % 2 == 1):
			var sc := 3 if ct < 0.07 else 2
			var half := PText.width("¡CRÍTICO!", sc) / 2.0
			var p := _screen(Fx.crit_text_at)
			var x := clampf(p.x, half + 2.0, W - half - 2.0)
			var y := maxf(22.0, p.y - 22.0 - 10.0 * minf(1.0, ct / 0.5)) + (roundf(sin(ct * 60.0) * 1.5) if ct < 0.2 else 0.0)
			var cols := [Pal.Y, Pal.W, Pal.O]
			_text("¡CRÍTICO!", x, y, cols[int(ct * 16.0) % 3], sc, 1, Pal.R)


func _draw_status() -> void:
	for i in player.max_hearts:
		var ht: Texture2D = HEART if i < player.hearts else HEART0
		canvas.draw_texture_rect(ht, Rect2(4 + i * 9, 4, ht.get_width() / 2.0, ht.get_height() / 2.0), false)
	_draw_energy()
	_draw_xp()
	# carga del arco: una rayita debajo de la experiencia
	if player.charge >= Player.CHG_ON:
		var k := clampf(player.charge / player.chg_full(), 0.0, 1.0)
		_rect(XPB.position.x - 0.5, 28.5, XPB.size.x + 1, 2, Pal.K)
		_fill(XPB.position.x, 29, XPB.size.x * k, 1, Pal.RAMP_Y if k >= 1.0 else Pal.RAMP_S)
	# puntos (con la moneda al lado) y combo
	var bump := -1.0 if main.score_bump > 0.5 else 0.0
	var sc := "%05d" % roundi(main.shown_score)
	_text(sc, W - 4, 4 + bump, Pal.W if main.score_bump > 0.5 else Pal.Y, 1, 2)
	canvas.draw_texture_rect(COIN, Rect2(W - 4 - PText.width(sc) - 9.0, 2.0 + bump, COIN.get_width() / 2.0, COIN.get_height() / 2.0), false)
	if main.combo > 1:
		_text("x%d" % main.combo, W - 4, 12, Pal.C, 1, 2)
	# zona y slimes que quedan
	if main.z < 3:
		var left: int = main.alive_in_zone(main.z)
		_text("ZONA %d" % (main.z + 1) + ("" if main.cleared else " · ENEMIGOS %d" % left), W / 2.0, 4, Pal.S)
		if main.cleared and main.gates[main.z].open > 0.5 and int(t * 4.0) % 2 == 1:
			_text("SEGUÍ >", W - 6, 96, Pal.Y, 1, 2)
	# barra del jefe: marco de hierro y oro con el yelmo en el medallón
	var b = main.boss
	if b != null and is_instance_valid(b) and not b.state in ["wait", "drop", "gone"]:
		var shx := roundf(randf_range(-2, 2)) if b.bar_shake > 0.0 else 0.0
		var r := Rect2(BOSS.position + Vector2(shx, 0), BOSS.size)
		var name_col := (Pal.R if int(t * 8.0) % 2 == 1 else Pal.Y) if b.phase >= 3 else (Pal.O if b.phase >= 2 else Pal.S)
		_text("MEGA CABALLERO", W / 2.0, 3, name_col)
		_frame(BAR_BOSS, r, Vector2(22, 8))
		var fill: float = b.fill
		var x := r.position.x
		var y := r.position.y
		var bw := r.size.x
		_fill(x, y, bw * b.shown_hp / b.max_hp * fill, 4, Pal.RAMP_W, false)
		var hw: float = bw * b.hp / b.max_hp * fill
		var ramp: Array = Pal.RAMP_O if b.phase >= 2 else Pal.RAMP_R
		_fill(x, y, hw, 4, ramp)
		_shine(x, y, hw, 4, ramp, 0.8)
		for q in [0.25, 0.5, 0.75]:
			_rect(x + roundf(bw * q), y, 0.5, 4, Pal.K)
		_icon(ICON_BOSS, r.position - Vector2(11, 4) + Vector2(6, 6))


## Marco HD de una barra, corrido para que su hueco (que empieza en inner, en px de la textura) caiga en r.
func _frame(tx: Texture2D, r: Rect2, inner: Vector2, mod: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect(tx, Rect2(r.position - inner / 2.0, tx.get_size() / 2.0), false, mod)


## Ícono centrado en c, a su tamaño HD.
func _icon(tx: Texture2D, c: Vector2, mod: Color = Color.WHITE) -> void:
	var sz := tx.get_size() / 2.0
	canvas.draw_texture_rect(tx, Rect2((c - sz / 2.0).snapped(Vector2(0.5, 0.5)), sz), false, mod)


## Relleno con su rampa: brillo arriba, sombra abajo y la punta encendida.
func _fill(x: float, y: float, w: float, h: float, r: Array, edge: bool = true) -> void:
	w = roundf(w * 2.0) / 2.0
	if w <= 0.0:
		return
	_rect(x, y, w, h, r[2])
	_rect(x, y, w, 0.5, r[4])
	if h >= 2.0:
		_rect(x, y + 0.5, w, 0.5, r[3])
	_rect(x, y + h - 0.5, w, 0.5, r[1])
	if edge and w >= 1.0:
		_rect(x + w - 0.5, y, 0.5, h, r[4])


## Un brillo que recorre la barra cada tanto.
func _shine(x: float, y: float, w: float, h: float, r: Array, speed: float = 1.0) -> void:
	var p := fmod(t * speed, 2.6) / 2.6
	var sx := roundf((p * (w + 50.0) - 4.0) * 2.0) / 2.0
	if sx < 0.0 or sx + 1.5 > w:
		return
	_rect(x + sx, y, 1.0, h, r[4])
	_rect(x + sx + 1.0, y, 0.5, h, r[3])


## Energía con marcas de lo que cuesta el especial (dash, escudo o furia); con veneno titila en verde,
## con el escudo levantado baja en celeste y en furia late en rojo.
func _draw_energy() -> void:
	var x := EN.position.x
	var y := EN.position.y
	var w := EN.size.x
	var h := EN.size.y
	var cost := player.special_cost()
	var k := clampf(player.energy / Player.EN_MAX, 0.0, 1.0)
	var warn := player.energy_flash > 0.0 and int(player.energy_flash * 16.0) % 2 == 1
	_frame(BAR_EN, EN, Vector2(20, 7), Color(1.0, 0.3, 0.35) if warn else Color.WHITE)
	var ready := player.energy >= cost
	var ramp: Array = Pal.RAMP_C if ready else Pal.RAMP_BB
	if player.venom:
		ramp = Pal.RAMP_L if int(t * 10.0) % 2 == 1 else Pal.RAMP_G
	elif player.shield:
		ramp = Pal.RAMP_W if int(t * 12.0) % 2 == 1 else Pal.RAMP_C
	elif player.rage_t > 0.0:
		ramp = Pal.RAMP_R if int(t * (16.0 if player.rage_t < 1.0 else 8.0)) % 2 == 1 else Pal.RAMP_O
	_fill(x, y, w * k, h, ramp)
	if ready or player.rage_t > 0.0:
		_shine(x, y, w * k, h, ramp)
	# lo que queda de furia: una rayita roja debajo
	if player.rage_t > 0.0:
		var rk := clampf(player.rage_t / (Player.RAGE_T * (2.0 if player.has_card("ira") else 1.0)), 0.0, 1.0)
		_rect(x, y + h, w * rk, 0.5, Pal.R)
	# marcas: cada dash, o lo que cuesta la furia; el escudo (barato) no lleva
	if cost >= 20.0:
		var c := cost
		while c < Player.EN_MAX:
			_rect(x + roundf(w * c / Player.EN_MAX * 2.0) / 2.0, y, 0.5, h, Pal.K)
			c += cost
	_icon(ICON_EN, EN.position - Vector2(10, 3.5) + Vector2(5, 5), Color.WHITE if ready else Color(0.5, 0.55, 0.8))


## Experiencia; ya evolucionado, la barra llena y el nombre en dorado.
func _draw_xp() -> void:
	var x := XPB.position.x
	var y := XPB.position.y
	var w := XPB.size.x
	var h := XPB.size.y
	_frame(BAR_XP, XPB, Vector2(20, 8))
	if player.evo:
		_fill(x, y, w, h, Pal.RAMP_Y)
		_shine(x, y, w, h, Pal.RAMP_Y, 1.4)
		_text(Player.HEROES[player.kind].evo, x + w + 6, y - 0.5, Pal.W if int(t * 2.0) % 4 == 0 else Pal.Y, 1, 0, Pal.K)
	else:
		var flash: bool = main.xp_bump > 0.5 and int(t * 20.0) % 2 == 1
		_fill(x, y, w * minf(1.0, float(main.xp) / main.XP_EVO), h, Pal.RAMP_W if flash else Pal.RAMP_Y)
		_text("EXP", x + w + 6, y - 0.5, Pal.S, 1, 0)
	_icon(ICON_XP, XPB.position - Vector2(10, 4) + Vector2(5, 5))


func _draw_banner() -> void:
	var b: Dictionary = main.banner
	if b.text == "":
		return
	var bt: float = b.t
	if bt > (2.6 if b.long else 1.9):
		return
	if b.card:
		# presentación: una franja que entra de costado con el nombre grande
		var e := 1.0 - pow(1.0 - clampf(bt / 0.45, 0.0, 1.0), 3.0)
		var out := 1.0 - pow(1.0 - clampf((bt - 2.2) / 0.35, 0.0, 1.0), 3.0) if bt > 2.2 else 0.0
		var bx := (1.0 - e) * -W + out * W
		_rect(bx, 42, W, 40, Color(0.04, 0.03, 0.06, 0.82))
		_rect(bx, 42, W, 1, Pal.R)
		_rect(bx, 81, W, 1, Pal.R)
		_rect(bx + 20, 76, W - 40, 1, Pal.O)
		_text(b.text, W / 2.0 + bx + (1.0 - e) * 30.0, 48, Pal.Y, 3, 1, Pal.R, Pal.RAMP_Y)
		if b.sub != "":
			_text(b.sub, W / 2.0 - bx * 0.6, 69, Pal.W)
		return
	var end := 2.3 if b.long else 1.6
	if bt >= end and int(bt * 12.0) % 2 == 0:
		return
	var k := minf(1.0, bt / 0.35)
	var y := -14.0 + 60.0 * (1.0 - pow(1.0 - k, 3.0)) + (sin(k * PI) * 4.0 if bt < 0.5 else 0.0)
	_text(b.text, W / 2.0, y, Pal.Y, 2, 1, Color(0, 0, 0, 1), Pal.RAMP_Y)
	if b.sub != "":
		_text(b.sub, W / 2.0, y + 14, Pal.S)


# ---------------------------------------------------------------- cartas

func _wrap(s: String, n: int) -> Array:
	var out: Array = []
	var line := ""
	for word in PText.norm(s).split(" "):
		if line != "" and (line + " " + word).length() > n:
			out.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		out.append(line)
	return out


func _draw_card(c: Dictionary, x: float, on: bool, dim: bool, picked: bool) -> void:
	var w := CARD_W
	var h := CARD_H
	var y := 25.0 - (3.0 if on else 0.0)
	var ramp: Array = RAMPS.get(c.col, Pal.RAMP_S)
	var cr := Rect2(x - 2, y - 2, w + 4, h + 4)  # la textura tiene 2 de margen para el brillo
	canvas.draw_texture_rect(CARD, Rect2(cr.position + Vector2(2, 2), cr.size), false, Color(0, 0, 0, 0.7))
	if on:
		var lit := picked or int(t * 6.0) % 2 == 1
		canvas.draw_texture_rect(CARD_GLOW, cr, false, Color.WHITE if lit else Color(1, 0.6, 0.4))
	# la ventana del dibujo, con el color de la carta y rayos que giran despacio (el marco los recorta)
	var wx := x + 12.0
	var wy := y + 13.0
	var cc := Vector2(x + w / 2.0, wy + 19.0)
	_rect(wx, wy, 56, 38, ramp[0])
	for i in 8:
		var a := t * 0.5 + i * TAU / 8.0
		canvas.draw_colored_polygon(PackedVector2Array([cc, cc + Vector2(cos(a - 0.17), sin(a - 0.17)) * 30.0,
			cc + Vector2(cos(a + 0.17), sin(a + 0.17)) * 30.0]), ramp[1])
	Pix.disc_dither(canvas, cc, 15.0, ramp[1])
	Pix.disc_dither(canvas, cc, 10.0, ramp[2], true)
	canvas.draw_texture_rect(CARD, cr, false)
	var bob := roundf(sin(t * 5.0)) if on and not picked else 0.0
	var ik: String = c.id + "_" + player.kind
	if not icons.has(ik):
		ik = c.id
	if icons.has(ik):
		var it: Texture2D = icons[ik]
		var isz := it.get_size() / 2.0  # los de PixelLab van a su tamaño HD; los viejos de 24 px, al doble
		if isz.x < 16.0:
			isz *= 2.0
		canvas.draw_texture_rect(it, Rect2(Pix.snapv(cc - isz / 2.0 + Vector2(0, bob)), isz), false)
	_text(Player.HEROES[c.only].name if c.has("only") else "HÉROE", x + w / 2.0, y + 4, Pal.W, 1, 1, Pal.RAMP_R[0])
	# nombre y efecto
	var lines := _wrap(main.card_name(c), 12).slice(0, 2)
	for j in lines.size():
		_text(lines[j], x + w / 2.0, y + 55 + j * 8 + (4 if lines.size() == 1 else 0), Pal.Y if on else Pal.W)
	var desc := _wrap(c.desc, 12).slice(0, 3)
	for j in desc.size():
		_text(desc[j], x + w / 2.0, y + 76 + j * 7, Pal.S, 1, 1, Color(0, 0, 0, 0))
	if dim:
		canvas.draw_texture_rect(CARD, cr, false, Color(0.04, 0.04, 0.09, 0.6))
		_rect(wx, wy, 56, 38, Color(0.04, 0.04, 0.09, 0.6))
	if on and not picked:
		var ay := y + h + 3 + (int(t * 4.0) % 2)
		for k in 4:
			_rect(x + w / 2.0 - 3 + k, ay + k, 7 - k * 2, 1, Pal.Y)
	if picked:
		_text("¡ELEGIDA!", x + w / 2.0, y + h + 3, Pal.Y)


func _draw_picker() -> void:
	var pk: Dictionary = main.pick
	_rect(0, 0, W, H, Color(0.04, 0.04, 0.09, 0.78))
	_text("¡LISTO!" if pk.done else "ELEGÍ UNA CARTA", W / 2.0, 3, Pal.Y, 2, 1, Color(0, 0, 0, 1), Pal.RAMP_Y)
	_text("PARA EL " + Player.HEROES[player.kind].name, W / 2.0, 16, Pal.S)
	var ids: Array = pk.ids
	var n := ids.size()
	for i in n:
		var x := roundf(W / 2.0 - (n * 80 + (n - 1) * 5) / 2.0 + i * 85)
		_draw_card(main.card_of(ids[i]), x, i == pk.sel, pk.done and i != pk.sel, pk.done and i == pk.sel)
	if not pk.done:
		_text("< > ELEGIR · ATAQUE O SALTO CONFIRMA", W / 2.0, 136, Pal.Y)


# ---------------------------------------------------------------- pantallas

func _draw_title() -> void:
	_rect(0, 0, W, H, Color(0.04, 0.03, 0.1, 0.35))
	_text("PIP Y LOS", W / 2.0, 22, Pal.W, 2, 1, Color(0, 0, 0, 1), Pal.RAMP_W)
	_text("SLIMES", W / 2.0, 36, Pal.Y, 4, 1, Pal.R, Pal.RAMP_Y)
	_text("· EDICIÓN GODOT ·", W / 2.0, 62, Pal.C)
	if int(t * 2.0) % 2 == 0:
		_text("SALTO O ATAQUE PARA EMPEZAR", W / 2.0, 74, Pal.Y)
	if main.best > 0:
		_text("RÉCORD %d" % main.best, W / 2.0, 83, Pal.S)
	# el héroe elegido, parado en la pradera: izquierda y derecha lo cambian
	var hx := _screen(player.global_position).x
	var hname: String = Player.HEROES[player.kind].name
	var bl := int(t * 3.0) % 2 == 0
	_text(hname, hx, 94, Pal.Y, 1, 1, Pal.K)
	var half := PText.width(hname) / 2.0
	_text("<", hx - half - 6 - (1 if bl else 0), 94, Pal.W if bl else Pal.S, 1, 1, Pal.K)
	_text(">", hx + half + 6 + (1 if bl else 0), 94, Pal.W if bl else Pal.S, 1, 1, Pal.K)
	# los controles de ese héroe
	var lines: Array = {
		"archer": ["Z SALTO · X FLECHA", "MANTENÉ X: FLECHAZO", "SHIFT: DASH · C: VENENO"],
		"knight": ["Z SALTO · X ESPADA", "MANTENÉ X: ESPADAZO", "SHIFT: ESCUDO (PARRY)"],
		"barb": ["Z SALTO · X HACHA", "MANTENÉ X: GIRO", "SHIFT: FURIA"],
	}.get(player.kind, [])
	for i in lines.size():
		_text(lines[i], 160, 92 + i * 8, Pal.S)
	# slimes y una moneda en el piso, como en el título del original
	var f := int(t * 8.0) % 8
	var sq := sin(t * 6.0) * 0.08
	_slime(Vector2(160, 128), 0, f, Vector2(1 + sq, 1 - sq))
	var f2 := int(t * 12.0 + 3) % 8
	var sq2 := sin(t * 9.0) * 0.1
	_slime(Vector2(182, 128), 1, f2, Vector2(1 + sq2, 1 - sq2))
	var fw := COIN_SPIN.get_width() / 8.0
	var cf := int(fmod(t * 3.2, PI) / PI * 8.0) % 8
	canvas.draw_texture_rect_region(COIN_SPIN, Rect2(197, 108 + roundf(sin(t * 4.0) * 1.5), fw / 2.0, COIN_SPIN.get_height() / 2.0),
		Rect2(cf * fw, 0, fw, COIN_SPIN.get_height()))


func _slime(feet: Vector2, row: int, frame: int, sq: Vector2) -> void:
	var w := 16.0 * sq.x
	var h := 13.0 * sq.y
	canvas.draw_texture_rect_region(SLIMES, Rect2(feet.x - w / 2.0, feet.y - h + 0.5, w, h), Rect2(frame * 32, row * 26, 32, 26))


func _draw_over() -> void:
	_rect(0, 0, W, H, Color(0.1, 0.11, 0.17, 0.72))
	_text("FIN DEL JUEGO", W / 2.0, 22, Pal.R, 3, 1, Pal.K, Pal.RAMP_R)
	_text("PUNTOS %d" % main.score, W / 2.0, 46, Pal.Y)
	_text("RÉCORD %d" % maxi(main.best, main.score), W / 2.0, 56, Pal.S)
	if main.end_t > 1.2 and int(t * 2.0) % 2 == 0:
		_text("SALTO: ELEGIR HÉROE · R: REINTENTAR", W / 2.0, 80, Pal.W)


func _draw_win() -> void:
	_rect(0, 0, W, H, Color(0.1, 0.11, 0.17, 0.6))
	_text("¡VICTORIA!", W / 2.0, 22, Pal.Y, 3, 1, Pal.R, Pal.RAMP_Y)
	_text("PUNTOS %d" % main.score, W / 2.0, 46, Pal.W)
	_text("RÉCORD %d" % maxi(main.best, main.score), W / 2.0, 56, Pal.S)
	if main.end_t > 3.2 and int(t * 2.0) % 2 == 0:
		_text("SALTO: ELEGIR HÉROE · R: REINTENTAR", W / 2.0, 80, Pal.W)
