extends RefCounted
## El bot que maneja a un héroe en el modo Villano (botThink, botClimb y botDodge del original).
## No toca al héroe: cada cuadro decide qué acciones "aprieta" (p.inp) y el héroe hace el resto con
## las mismas reglas que cuando lo maneja una persona.
## - Piensa cada "react" segundos: busca al enemigo más cercano de la zona y decide para dónde ir.
## - Arquero y mago guardan distancia; caballero y bárbaro van al cuerpo a cuerpo.
## - Si el enemigo está arriba, busca la plataforma que le sirve de escalón y salta; si está abajo, se deja caer.
## - Esquiva la baba que le viene cayendo, pero no siempre: cada baba la "ve" o no según su habilidad.

const GROUND := 128.0

var game                    # main.gd
var react := 0.2            # cada cuánto piensa
var guard_t := 0.0           # caballero: cada cuánto vuelve a decidir si se cubre de una amenaza
var guard_ok := false
var skill := 0.62            # probabilidad de ver venir cada baba
var think_t := 0.0
var move := 0               # -1, 0, 1
var step = null             # plataforma [x, y, ancho] a la que quiere subir
var jump_hold := 0.0        # mantiene el salto apretado este tiempo
var jump_gap := 0.0         # un cuadro sin salto para que el próximo cuente como recién apretado
var drop := false
var atk_hold := 0.0
var atk_cd := 0.0
var spc_hold := 0.0
var spc_cd := 0.0
var seen := {}
var leap2 := -1.0            # salto doble pendiente: en cuánto aprieta el segundo
var leap_t := 0.0            # está saltando la embestida del jefe: sigue de largo hacia este lado
var leap_dir := 0
var wait_x := 0.0           # cada uno espera un poco más o menos lejos del portón, para no amontonarse


func _init() -> void:
	react = 0.14 + randf() * 0.14
	wait_x = randf() * 30.0
	atk_cd = 1.2 + randf() * 0.8
	spc_cd = 2.5 + randf() * 2.0
	think_t = 1.0 + randf() * 0.8   # arrancan con un instante de duda, mientras pasa el cartel


func think(p: Player, dt: float) -> void:
	think_t -= dt
	atk_cd -= dt
	spc_cd -= dt
	jump_hold -= dt
	jump_gap -= dt
	leap_t -= dt
	if leap2 > 0.0:
		leap2 -= dt
		if leap2 <= 0.0:  # el segundo salto, en el aire: suelta un cuadro y vuelve a apretar
			jump_gap = 0.03
			jump_hold = 0.34
	atk_hold -= dt
	spc_hold -= dt
	drop = false
	var playing: bool = game != null and game.state == "play"
	if not playing or p.dead:
		p.inp = {}
		return
	if think_t <= 0.0:
		think_t = react
		_decide(p)
	_climb(p)
	_dodge(p)
	_guard(p, dt)
	_leap(p)
	_sweep_guard(p)
	p.inp = {
		"derecha": move > 0, "izquierda": move < 0,
		"saltar": jump_hold > 0.0 and jump_gap <= 0.0,
		"abajo": drop,
		"atacar": atk_hold > 0.0,
		"especial": spc_hold > 0.0,
		"poder": false,
	}


func _jump() -> void:
	if jump_hold > 0.0:
		return
	jump_hold = 0.26
	jump_gap = 0.0


func _attack(p: Player) -> void:
	if atk_cd > 0.0:
		return
	atk_hold = 0.05
	# el caballero y el bárbaro pegan más seguido: pelean pegados al enemigo y cada golpe que tardan es un toque que reciben
	var slow := 0.25 + randf() * 0.3 if p.kind == "knight" or p.kind == "barb" else 0.55 + randf() * 0.5
	atk_cd = float(Player.HEROES[p.kind].cool) + slow


func _on_platform(p: Player) -> bool:
	return p.is_on_floor() and p.global_position.y < GROUND - 2.0


func _decide(p: Player) -> void:
	var z: int = game.z
	var foot := p.global_position.y
	var cx := p.global_position.x
	var target = null
	var bd := 1e9
	for m in p.get_tree().get_nodes_in_group("enemigos"):
		if m.dead or m.spawn > 0.0 or m.zone != z:
			continue
		var d: float = absf(m.global_position.x - cx) + absf(m.global_position.y - foot) * 2.0
		if d < bd:
			bd = d
			target = m
	step = null
	var tpos := Vector2.ZERO
	if target != null:
		tpos = target.global_position
	elif z >= 3:
		# el Salón del Trono: el Mega Caballero (se le pega desde el piso, aunque esté saltando)
		var b = game.boss
		if b == null or not is_instance_valid(b) or not b.active():
			move = 0
			return
		target = b
		tpos = Vector2(b.cx(), b.GROUND)
		_boss(p, b)
		return
	if target == null:
		# no queda nadie: cuando el portón se abre, cruza y espera del otro lado
		var gx: float = game.gates[z].x
		if game.gates[z].open < 0.85:
			move = 0
		elif cx > gx + 26.0 + wait_x:
			move = 0
		else:
			move = 1
			if _on_platform(p) and gx - cx < 60.0:
				drop = true
				jump_hold = 0.06
		return
	var tx: float = tpos.x
	var dx := tx - cx
	var dist := absf(dx)
	var toward := 1 if dx >= 0.0 else -1
	var dy: float = tpos.y - foot
	var zd: Dictionary = game.ZONES[z]
	var wall_behind: bool = (toward > 0 and cx < zd.start + 16) or (toward < 0 and cx > game.gates[z].x - 24)
	move = toward
	if absf(dy) < 14.0:
		if p.kind == "archer":
			move = -toward if dist < 46.0 and not wall_behind else (toward if dist > 110.0 else 0)
			if dist < 160.0 and p.face == toward:
				_attack(p)
		elif p.kind == "mage":
			move = -toward if dist < 30.0 and not wall_behind else (toward if dist > 92.0 else 0)
			if spc_cd <= 0.0 and p.energy >= Player.FIRE_COST and dist > 24.0 and dist < 130.0 and p.face == toward:
				spc_hold = 0.05
				spc_cd = 2.2 + randf() * 1.6
			elif dist < 22.0:
				_attack(p)
		else:
			# se para a la distancia de su arma, no encima del enemigo (tocarlo lastima)
			move = toward if dist > 18.0 else 0
			if dist < 25.0:
				_attack(p)
		# parado pero mirando para el otro lado: un pasito para darse vuelta
		if move == 0 and p.face != toward:
			move = toward
	elif dy < -14.0:
		# el enemigo está arriba: la plataforma más cercana a él que le quede a un salto
		var best = null
		var bx := 1e9
		for pl in game.PLATS:
			if pl[0] < zd.start or pl[0] >= zd.end:
				continue
			# hasta 34 px llega con un salto; hasta 68, con el doble (si no, el que se sube a una
			# plataforma alta queda fuera del alcance de todos)
			if pl[1] < foot - 4.0 and pl[1] >= foot - 68.0:
				var d2 := absf(pl[0] + pl[2] / 2.0 - tx)
				if d2 < bx:
					bx = d2
					best = pl
		step = best
		if best != null:
			var near := clampf(cx, best[0] + 6.0, best[0] + best[2] - 6.0)
			move = (1 if near > cx else -1) if absf(near - cx) > 3.0 else toward
		if p.melee() and dist < 24.0 and dy > -26.0:
			_attack(p)
	else:
		# está abajo: va hacia él y se deja caer de la plataforma
		move = toward
		if dist < 22.0 and _on_platform(p):
			drop = true
			jump_hold = 0.06
			jump_gap = 0.0


## Contra el Mega Caballero: los de espada se le pegan y se apartan cuando levanta la espada; la embestida la saltan;
## el arquero y el mago le tiran de lejos. Todos bajan al piso.
func _boss(p: Player, b) -> void:
	var cx := p.global_position.x
	var dx: float = b.cx() - cx
	var dist := absf(dx)
	var toward := 1 if dx >= 0.0 else -1
	var lo: float = b.ARENA_MIN + 6.0
	var hi: float = b.ARENA_MAX - 6.0
	var cornered: bool = (toward > 0 and cx < lo + 14.0) or (toward < 0 and cx > hi - 14.0)
	if leap_t > 0.0 or b.charge_eta(cx) >= 0.0:
		return  # la embestida la resuelve _leap, cuadro a cuadro
	if _on_platform(p):
		drop = true
		jump_hold = 0.06
	# ve venir el golpe: el tajo (de frente y cerca), la embestida (salta) y el salto (se corre de donde cae)
	var danger := false
	if b.state == "tele" or b.state == "act":
		var front: bool = signf(cx - b.cx()) == float(b.face)
		if b.atk == "sweep" and front and dist < 66.0:
			danger = true
		elif b.atk == "slam" and absf(b.target_x - cx) < 40.0:
			danger = true
		elif b.atk == "charge" and front:
			danger = true
	if danger:
		var k: int = b.get_instance_id() + int(b.clock * 2.0) * 13
		if not seen.has(k):
			seen[k] = randf() < skill
		if seen[k]:
			if b.atk == "slam":
				move = 1 if cx >= b.target_x else -1
				if (move > 0 and cx > hi - 10.0) or (move < 0 and cx < lo + 10.0):
					move = -move
			elif b.atk == "charge":
				move = -toward if not cornered else 0
			else:
				move = -toward if not cornered else toward
				if cornered:
					_jump()
			return
	if p.kind == "archer":
		# de lejos: fuera del alcance del tajo (llega a unos 62 px)
		move = -toward if dist < 76.0 and not cornered else (toward if dist > 130.0 else 0)
		if p.face == toward:
			_attack(p)
	elif p.kind == "mage":
		move = -toward if dist < 70.0 and not cornered else (toward if dist > 112.0 else 0)
		if spc_cd <= 0.0 and p.energy >= Player.FIRE_COST and dist > 24.0 and p.face == toward:
			spc_hold = 0.05
			spc_cd = 2.2 + randf() * 1.6
		elif dist < 26.0:
			_attack(p)
	else:
		move = toward if dist > 20.0 else 0
		if dist < 30.0:
			_attack(p)
	if move == 0 and p.face != toward:
		move = toward


## El tajo del Mega Caballero, cuadro a cuadro (el aviso dura menos que una pensada): el caballero lo frena
## con el escudo y los demás lo saltan con el salto doble, alejándose. No siempre lo ven venir.
func _sweep_guard(p: Player) -> void:
	var b = game.boss
	if game.z < 3 or b == null or not is_instance_valid(b) or not b.active() or b.atk != "sweep":
		return
	if b.state != "tele" and not (b.state == "act" and b.t < 0.16):
		return
	var cx := p.global_position.x
	var dist: float = absf(cx - b.cx())
	if signf(cx - b.cx()) != float(b.face) or dist > 68.0:
		return
	var k: int = b.atk_n * 17 + 3
	if not seen.has(k):
		seen[k] = randf() < maxf(skill, 0.8)
	if not seen[k]:
		return
	if p.kind == "knight" and (p.shield or p.energy >= Player.SH_MIN + 6.0):
		spc_hold = maxf(spc_hold, 0.2)
		atk_hold = 0.0
		return
	if b.state == "tele" and p.is_on_floor() and leap_t <= 0.0:
		var away := 1 if cx >= b.cx() else -1
		var cornered: bool = (away > 0 and cx > b.ARENA_MAX - 16.0) or (away < 0 and cx < b.ARENA_MIN + 16.0)
		jump_hold = 0.22
		jump_gap = 0.0
		leap2 = 0.2
		leap_t = 0.55
		leap_dir = 0 if cornered else away
		move = leap_dir


## La embestida del jefe no se salta con un salto solo (mide 40): salto doble justo antes de que llegue, yendo
## hacia él para pasarle por arriba y caer atrás. Si cae sobre el yelmo, encima lo pisa. Se mira cuadro a
## cuadro, porque entre pensada y pensada la embestida ya llegó.
func _leap(p: Player) -> void:
	if leap_t > 0.0:
		move = leap_dir
		return
	var b = game.boss
	if game.z < 3 or b == null or not is_instance_valid(b) or not b.active():
		return
	var cx := p.global_position.x
	var eta: float = b.charge_eta(cx)
	if eta < 0.0:
		return
	var k: int = b.atk_n * 31 + 7
	if not seen.has(k):
		seen[k] = randf() < maxf(skill, 0.7)  # la embestida se ve venir de lejos: la saltan 7 de cada 10 veces
	if not seen[k]:
		return
	var toward := 1 if b.cx() >= cx else -1
	if eta < 0.48 and eta > 0.1 and p.is_on_floor():
		jump_hold = 0.22
		jump_gap = 0.0
		leap2 = 0.2
		leap_t = 0.75
		leap_dir = toward
		move = toward
	elif _on_platform(p):
		move = 0  # arriba de una plataforma la embestida le pasa por abajo
	else:
		var cornered: bool = (toward > 0 and cx < b.ARENA_MIN + 20.0) or (toward < 0 and cx > b.ARENA_MAX - 20.0)
		move = 0 if cornered else -toward


## Los de cuerpo a cuerpo se cuidan. El caballero levanta el escudo cuando algo lo va a tocar (un slime
## encima, una flecha, un hacha, una baba, el hachero levantando el hacha): recién levantado es un parry.
## El bárbaro entra en furia al llegar a la pelea y, mientras recarga el golpe, se aparta del que tiene encima.
func _guard(p: Player, dt: float) -> void:
	if p.kind != "knight" and p.kind != "barb":
		return
	guard_t -= dt
	var cx := p.global_position.x
	var foot := p.global_position.y
	var near = null
	var nd := 1e9
	for m in p.get_tree().get_nodes_in_group("enemigos"):
		if m.dead or m.spawn > 0.0 or absf(m.global_position.y - foot) > 16.0:
			continue
		var d := absf(m.global_position.x - cx)
		if d < nd:
			nd = d
			near = m
	# pegan apenas el enemigo entra en el alcance del arma (cuadro a cuadro: esperando a la próxima
	# pensada, el slime ya lo tocó)
	if near != null and nd < 25.0 and atk_cd <= 0.0 and not p.shield:
		var tw := 1 if near.global_position.x >= cx else -1
		if p.face != tw:
			move = tw
		else:
			_attack(p)
	if p.kind == "barb":
		if near == null:
			return
		if nd < 46.0 and p.energy >= Player.RAGE and p.rage_t <= 0.0 and spc_hold <= 0.0 and spc_cd <= 0.0:
			spc_hold = 0.05
			spc_cd = 1.0
		if nd < (26.0 if p.hearts <= 2 else 21.0) and atk_cd > 0.15:
			var away := -1 if near.global_position.x >= cx else 1
			var zd: Dictionary = game.ZONES[mini(game.z, 3)]
			if cx + away * 14.0 > zd.start + 8.0 and cx + away * 14.0 < zd.end - 8.0:
				move = away
		return
	# caballero
	var threat := false
	if near != null:
		if nd < 13.0 and atk_cd > 0.1:
			threat = true
		elif near.get("kind") == "skaxe" and near.windup > 0.0 and nd < 30.0:
			threat = true
	if not threat:
		for a in p.get_tree().get_nodes_in_group("flechas_malas"):
			if a.stuck or a.hero:
				continue
			var da: float = (cx - a.global_position.x) * a.face
			if da > 0.0 and da < 42.0 and absf(a.global_position.y - (foot - 11.0)) < 12.0:
				threat = true
				break
	if not threat:
		for a in p.get_tree().get_nodes_in_group("hachas"):
			if not a.lost and absf(a.global_position.x - cx) < 34.0 and absf(a.global_position.y - (foot - 11.0)) < 14.0:
				threat = true
				break
	if not threat:
		for s in p.get_tree().get_nodes_in_group("babas"):
			if s.vel.y > 0.0 and absf(s.global_position.x - cx) < 16.0 and s.global_position.y < foot and foot - s.global_position.y < 40.0:
				threat = true
				break
	if not threat:
		return
	if guard_t <= 0.0:
		guard_t = 0.7
		guard_ok = randf() < skill + 0.2
	if guard_ok and (p.shield or p.energy >= Player.SH_MIN + 10.0):
		spc_hold = maxf(spc_hold, 0.14)
		atk_hold = 0.0


func _climb(p: Player) -> void:
	if step == null:
		return
	var cx := p.global_position.x
	var mid: float = step[0] + step[2] / 2.0
	if not p.is_on_floor():
		if absf(mid - cx) > 2.0:
			move = 1 if mid > cx else -1
		return
	var near := clampf(cx, step[0] + 6.0, step[0] + step[2] - 6.0)
	var under: bool = cx > step[0] - 16.0 and cx < step[0] + step[2] + 16.0
	# parado en otra plataforma: salta al llegar al borde que da hacia el escalón
	var edge := false
	if _on_platform(p) and absf(near - cx) > 3.0:
		var foot := p.global_position.y
		for pl in game.PLATS:
			if absf(pl[1] - foot) < 2.0 and cx >= pl[0] - 2.0 and cx <= pl[0] + pl[2] + 2.0:
				var edge_x: float = pl[0] + pl[2] if near > cx else pl[0]
				edge = absf(edge_x - cx) < 9.0
				break
	if under or edge:
		if jump_hold <= 0.0 and p.global_position.y - step[1] > 32.0:
			leap2 = 0.2   # está alto: salto doble
		_jump()


func _dodge(p: Player) -> void:
	var cx := p.global_position.x
	var cy := p.global_position.y - 9.0
	for s in p.get_tree().get_nodes_in_group("babas"):
		if s.vel.y <= 0.0 or absf(s.global_position.x - cx) > 22.0 or s.global_position.y > cy:
			continue
		var key: int = s.get_instance_id()
		if not seen.has(key):
			seen[key] = randf() < skill
		if seen[key]:
			move = 1 if s.global_position.x < cx else -1
	# flechas de los esqueletos: salta la que le viene de frente a su altura
	for a in p.get_tree().get_nodes_in_group("flechas_malas"):
		if a.stuck or a.hero:
			continue
		var d: float = (cx - a.global_position.x) * a.face
		if d > 0.0 and d < 50.0 and absf(a.global_position.y - (p.global_position.y - 11.0)) < 8.0 and p.is_on_floor():
			var k2: int = a.get_instance_id()
			if not seen.has(k2):
				seen[k2] = randf() < skill
			if seen[k2]:
				_jump()
	# espadas de costado (el castigo del portón): las salta igual que a una flecha
	for a in p.get_tree().get_nodes_in_group("espadas_lado"):
		if a.warn > 0.0:
			continue
		var ds: float = (cx - a.global_position.x) * a.dir
		if ds > 0.0 and ds < 46.0 and absf(a.global_position.y - (p.global_position.y - 8.0)) < 9.0 and p.is_on_floor():
			var ks: int = a.get_instance_id()
			if not seen.has(ks):
				seen[ks] = randf() < skill
			if seen[ks]:
				_jump()
	# el hacha que tiró el hachero (a la ida y a la vuelta): la salta
	for a in p.get_tree().get_nodes_in_group("hachas"):
		if a.lost:
			continue
		var av: float = a.dir
		if a.back and a.thrower != null and is_instance_valid(a.thrower):
			av = signf(a.thrower.global_position.x - a.global_position.x)
		var da: float = (cx - a.global_position.x) * av
		if da > 0.0 and da < 46.0 and absf(a.global_position.y - (p.global_position.y - 11.0)) < 13.0 and p.is_on_floor():
			var ka: int = a.get_instance_id() * 3 + int(a.back)
			if not seen.has(ka):
				seen[ka] = randf() < skill
			if seen[ka]:
				_jump()
	# el hachero que levantó el hacha: se aparta
	for m in p.get_tree().get_nodes_in_group("enemigos"):
		if m.get("kind") == "skaxe" and not m.dead and m.windup > 0.0 and absf(m.global_position.x - cx) < 28.0:
			var k3: int = m.get_instance_id() * 7 + int(m.cool * 10.0)
			if not seen.has(k3):
				seen[k3] = randf() < skill
			if seen[k3]:
				move = 1 if cx >= m.global_position.x else -1
	# ondas del salto del jefe: las salta; espadas que van a caer: se corre de abajo
	for w in p.get_tree().get_nodes_in_group("ondas"):
		if w.hero:
			continue
		var d2: float = (cx - w.global_position.x) * w.dir
		if d2 > 0.0 and d2 < 30.0 and p.is_on_floor():
			var k4: int = w.get_instance_id()
			if not seen.has(k4):
				seen[k4] = randf() < skill
			if seen[k4]:
				_jump()
	for hz in p.get_tree().get_nodes_in_group("peligros"):
		if hz.phase == "stuck" or absf(hz.global_position.x - cx) > 9.0:
			continue
		var k5: int = hz.get_instance_id()
		if not seen.has(k5):
			seen[k5] = randf() < skill
		if seen[k5]:
			move = 1 if cx >= hz.global_position.x else -1
	# --- el bosque ---
	# la telaraña: la salta como a una flecha
	for a in p.get_tree().get_nodes_in_group("telas"):
		var dw: float = (cx - a.global_position.x) * a.face
		if dw > 0.0 and dw < 50.0 and absf(a.global_position.y - (p.global_position.y - 9.0)) < 11.0 and p.is_on_floor():
			var kw: int = a.get_instance_id()
			if not seen.has(kw):
				seen[kw] = randf() < skill
			if seen[kw]:
				_jump()
	# las enredaderas que vienen por el piso: las salta cuando la punta está cerca
	for v in p.get_tree().get_nodes_in_group("enredaderas"):
		var head: float = v.global_position.x + v.dir * minf(v.gone, v.REACH)
		var dv: float = (cx - head) * v.dir
		if dv > -30.0 and dv < 26.0 and p.is_on_floor() and absf(p.global_position.y - v.floor_y) < 6.0:
			var kv: int = v.get_instance_id()
			if not seen.has(kv):
				seen[kv] = randf() < skill
			if seen[kv]:
				_jump()
	# la nube de esporas del hongo muerto: no se queda adentro (esto lo ven todos: es grande y dura)
	for c in p.get_tree().get_nodes_in_group("esporas"):
		if absf(c.global_position.x - cx) < c.RAD + 12.0 and absf(c.global_position.y - p.global_position.y) < 30.0:
			move = 1 if cx >= c.global_position.x else -1
	if seen.size() > 96:
		seen.clear()
