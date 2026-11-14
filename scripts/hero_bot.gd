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
var skill := 0.5            # probabilidad de ver venir cada baba
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


func _init() -> void:
	react = 0.14 + randf() * 0.14
	atk_cd = 1.2 + randf() * 0.8
	spc_cd = 2.5 + randf() * 2.0
	think_t = 1.0 + randf() * 0.8   # arrancan con un instante de duda, mientras pasa el cartel


func think(p: Player, dt: float) -> void:
	think_t -= dt
	atk_cd -= dt
	spc_cd -= dt
	jump_hold -= dt
	jump_gap -= dt
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
	atk_cd = float(Player.HEROES[p.kind].cool) + 0.55 + randf() * 0.5


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
	if target == null:
		move = 0
		return
	var tx: float = target.global_position.x
	var dx := tx - cx
	var dist := absf(dx)
	var toward := 1 if dx >= 0.0 else -1
	var dy: float = target.global_position.y - foot
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
			move = toward if dist > 15.0 else 0
			if dist < 24.0:
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
			if pl[1] < foot - 4.0 and pl[1] >= foot - 34.0:
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
	if under or (_on_platform(p) and absf(near - cx) > 3.0 and p.is_on_wall()):
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
	if seen.size() > 64:
		seen.clear()
