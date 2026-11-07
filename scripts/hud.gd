extends CanvasLayer
## Todo lo que va arriba del juego, con la fuente del original (PText) y en coordenadas de 256x144:
## corazones, energía, experiencia, puntos y combo, zona y slimes que quedan, barra del jefe,
## franjas de cine, pantalla roja, cuadro de impacto, ¡CRÍTICO!, carteles, elección de cartas,
## título, fin del juego y victoria. Sigue andando con el juego en pausa (para elegir cartas).

const W := 256.0
const H := 144.0
const HEART := preload("res://assets/sprites/items/heart.png")
const HEART0 := preload("res://assets/sprites/items/heart0.png")
const SLIMES := preload("res://assets/sprites/slimes.png")
const COIN := preload("res://assets/sprites/items/coin.png")
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
	for c in main.CARDS:
		var path: String = "res://assets/sprites/items/card_%s.png" % c.id
		if ResourceLoader.exists(path):
			icons[c.id] = load(path)


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
	if main.state == "title" and t > 0.3 and (Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("atacar")):
		main.start_game()
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
		canvas.draw_texture_rect(HEART if i < player.hearts else HEART0, Rect2(4 + i * 9, 4, 7, 6), false)
	_draw_energy(4, 13, 34)
	_draw_xp(4, 19, 34)
	# carga del arco
	if player.charge >= Player.CHG_ON:
		var k := clampf(player.charge / player.chg_full(), 0.0, 1.0)
		_rect(4, 24, 34 * k, 1, Pal.Y if k >= 1.0 else Pal.S)
	# puntos y combo
	var bump := -1.0 if main.score_bump > 0.5 else 0.0
	_text("%05d" % roundi(main.shown_score), W - 4, 4 + bump, Pal.W if main.score_bump > 0.5 else Pal.Y, 1, 2)
	if main.combo > 1:
		_text("x%d" % main.combo, W - 4, 12, Pal.C, 1, 2)
	# zona y slimes que quedan
	if main.z < 3:
		var left: int = main.alive_in_zone(main.z)
		_text("ZONA %d" % (main.z + 1) + ("" if main.cleared else " · ENEMIGOS %d" % left), W / 2.0, 4, Pal.S)
		if main.cleared and main.gates[main.z].open > 0.5 and int(t * 4.0) % 2 == 1:
			_text("SEGUÍ >", W - 6, 96, Pal.Y, 1, 2)
	# barra del jefe
	var b = main.boss
	if b != null and is_instance_valid(b) and not b.state in ["wait", "drop", "gone"]:
		var shx := roundf(randf_range(-2, 2)) if b.bar_shake > 0.0 else 0.0
		var bx := 68.0 + shx
		var by := 12.0
		var bw := 120.0
		var name_col := (Pal.R if int(t * 8.0) % 2 == 1 else Pal.Y) if b.phase >= 3 else (Pal.O if b.phase >= 2 else Pal.S)
		_text("MEGA CABALLERO", W / 2.0, 4, name_col)
		_rect(bx - 1.5, by - 1.5, bw + 3, 7, Pal.S)
		_rect(bx - 1, by - 1, bw + 2, 6, Pal.K)
		_rect(bx, by, bw, 4, Pal.D)
		var fill: float = b.fill
		_rect(bx, by, roundf(bw * b.shown_hp / b.max_hp * fill), 4, Pal.W)
		var hw := roundf(bw * b.hp / b.max_hp * fill)
		_rect(bx, by, hw, 4, Pal.O if b.phase >= 2 else Pal.R)
		_rect(bx, by, hw, 1, Pal.Y if b.phase >= 2 else Pal.O)
		_rect(bx + bw / 2.0, by, 1, 4, Pal.K)
		_rect(bx + bw / 4.0, by, 1, 4, Pal.K)


## Energía con marcas de lo que cuesta el dash; con veneno titila en verde.
func _draw_energy(x: float, y: float, w: float) -> void:
	var cost := player.dash_cost()
	var k := clampf(player.energy / Player.EN_MAX, 0.0, 1.0)
	var warn := player.energy_flash > 0.0 and int(player.energy_flash * 16.0) % 2 == 1
	_rect(x - 1, y - 1, w + 2, 5, Pal.R if warn else Pal.K)
	_rect(x, y, w, 3, Pal.D)
	var ready := player.energy >= cost
	var col := Pal.C if ready else Pal.BB
	if player.venom:
		col = Pal.L if int(t * 10.0) % 2 == 1 else Pal.G
	_rect(x, y, roundf(w * k), 3, col)
	_rect(x, y, roundf(w * k), 1, Pal.W if ready else Pal.B)
	var c := cost
	while c < Player.EN_MAX:
		_rect(x + roundf(w * c / Player.EN_MAX), y, 1, 3, Pal.K)
		c += cost


## Experiencia; ya evolucionado, el nombre en dorado.
func _draw_xp(x: float, y: float, w: float) -> void:
	if player.evo:
		_text("CAZADOR", x, y, Pal.W if int(t * 2.0) % 4 == 0 else Pal.Y, 1, 0, Pal.K)
		return
	_rect(x - 1, y - 1, w + 2, 4, Pal.K)
	_rect(x, y, w, 2, Pal.D)
	var c := Pal.W if main.xp_bump > 0.5 and int(t * 20.0) % 2 == 1 else Pal.Y
	_rect(x, y, roundf(w * minf(1.0, float(main.xp) / main.XP_EVO)), 2, c)
	_text("EXP", x + w + 4, y - 1, Pal.S, 1, 0)


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
	var w := 80.0
	var h := 98.0
	var y := 25.0 - (3.0 if on else 0.0)
	var frame: Array = Pal.RAMP_G
	var ramp: Array = RAMPS.get(c.col, Pal.RAMP_S)
	_rect(x + 2, y + 2, w, h, Pal.K)
	_rect(x - 1, y - 1, w + 2, h + 2, ((Pal.Y if picked or int(t * 6.0) % 2 == 1 else Pal.O) if on else frame[1]))
	_rect(x, y, w, h, Pal.K)
	_rect(x + 2, y + 2, w - 4, h - 4, frame[2])
	_rect(x + 3, y + 3, w - 6, h - 6, Color("10121e"))
	# cinta de arriba
	_rect(x + 8, y + 1, w - 16, 9, frame[1])
	_rect(x + 8, y + 1, w - 16, 1, frame[3])
	_text("ARQUERO" if c.get("only", false) else "HÉROE", x + w / 2.0, y + 2, Pal.W)
	# ventana del dibujo con el color de la carta
	_rect(x + 12, y + 13, w - 24, 38, ramp[0])
	_rect(x + 12, y + 13, w - 24, 2, ramp[1])
	_rect(x + 12, y + 47, w - 24, 4, ramp[1])
	for k in 5:
		_rect(x + 14 + k * 11, y + 15, 1, 32, Color(1, 1, 1, 0.08))
	var bob := roundf(sin(t * 5.0)) if on and not picked else 0.0
	if icons.has(c.id):
		canvas.draw_texture_rect(icons[c.id], Rect2(x + w / 2.0 - 12, y + 19 + bob, 24, 24), false)
	# nombre y efecto
	var lines := _wrap(c.name, 12).slice(0, 2)
	for j in lines.size():
		_text(lines[j], x + w / 2.0, y + 55 + j * 8 + (4 if lines.size() == 1 else 0), Pal.W)
	_rect(x + 10, y + 72, w - 20, 1, frame[1])
	var desc := _wrap(c.desc, 12).slice(0, 3)
	for j in desc.size():
		_text(desc[j], x + w / 2.0, y + 75 + j * 7, Pal.S, 1, 1, Color(0, 0, 0, 0))
	# corazoncito del héroe en la esquina
	_rect(x + w - 8, y + h - 8, 1, 1, Pal.L)
	_rect(x + w - 6, y + h - 8, 1, 1, Pal.L)
	_rect(x + w - 8, y + h - 7, 3, 1, Pal.L)
	_rect(x + w - 7, y + h - 6, 1, 1, Pal.L)
	if dim:
		_rect(x - 1, y - 1, w + 4, h + 4, Color(0.04, 0.04, 0.09, 0.6))
	if on and not picked:
		var ay := y + h + 3 + (int(t * 4.0) % 2)
		for k in 4:
			_rect(x + w / 2.0 - 3 + k, ay + k, 7 - k * 2, 1, Pal.Y)
	if picked:
		_text("¡ELEGIDA!", x + w / 2.0, y + h - 1, Pal.Y)


func _draw_picker() -> void:
	var pk: Dictionary = main.pick
	_rect(0, 0, W, H, Color(0.04, 0.04, 0.09, 0.78))
	_text("¡LISTO!" if pk.done else "ELEGÍ UNA CARTA", W / 2.0, 3, Pal.Y, 2, 1, Color(0, 0, 0, 1), Pal.RAMP_Y)
	_text("PARA EL ARQUERO", W / 2.0, 16, Pal.S)
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
	_text("< > MOVER · Z SALTO · X FLECHA", W / 2.0, 93, Pal.S)
	_text("MANTENÉ X: FLECHAZO · SHIFT: DASH", W / 2.0, 101, Pal.S)
	_text("C: VENENO DEL CAZADOR · R: REINICIAR", W / 2.0, 109, Pal.S)
	# slimes y una moneda en el piso, como en el título del original
	var f := int(t * 8.0) % 8
	var sq := sin(t * 6.0) * 0.08
	_slime(Vector2(160, 128), 0, f, Vector2(1 + sq, 1 - sq))
	var f2 := int(t * 12.0 + 3) % 8
	var sq2 := sin(t * 9.0) * 0.1
	_slime(Vector2(182, 128), 1, f2, Vector2(1 + sq2, 1 - sq2))
	canvas.draw_texture_rect(COIN, Rect2(197, 108 + roundf(sin(t * 4.0) * 1.5), 6, 7), false)


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
		_text("SALTO PARA JUGAR DE NUEVO", W / 2.0, 80, Pal.W)


func _draw_win() -> void:
	_rect(0, 0, W, H, Color(0.1, 0.11, 0.17, 0.6))
	_text("¡VICTORIA!", W / 2.0, 22, Pal.Y, 3, 1, Pal.R, Pal.RAMP_Y)
	_text("PUNTOS %d" % main.score, W / 2.0, 46, Pal.W)
	_text("RÉCORD %d" % maxi(main.best, main.score), W / 2.0, 56, Pal.S)
	if main.end_t > 3.2 and int(t * 2.0) % 2 == 0:
		_text("SALTO PARA JUGAR DE NUEVO", W / 2.0, 80, Pal.W)
