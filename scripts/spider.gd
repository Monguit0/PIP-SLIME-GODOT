extends CharacterBody2D
## Araña del Bosque Oscuro. Camina por el piso (vista de costado) y:
## - ataque: escupe una telaraña que saca 1 y deja al héroe muy lento (ver web.gd);
## - especial: lanza su hilo en diagonal hacia arriba y adelante, se engancha y queda colgada (vista de frente):
##   se hamaca con izquierda y derecha, trepa manteniendo arriba, baja con abajo, y volviendo a apretar el
##   especial (o el salto) corta el hilo y sale despedida con el envión que traía.
## Colgada también escupe, en diagonal hacia abajo. Si toca a un héroe hamacándose, lo lastima.
## En el modo Villano la podés manejar; si no, la maneja el juego (camina, escupe y cada tanto se cuelga).

const GRAV := 900.0
const DIR := "res://assets/sprites/bosque/arana/"
const CANVAS := 64.0
const FOOT_Y := 62.0
const HANG_C := 32.0          # centro del cuerpo en los cuadros "colgada"
const HP := 3
const SPEED := 36.0
const PSPEED := 64.0
const VJUMP := 240.0
const WEB_COOL := 0.9
const ROPE_MIN := 14.0
const ROPE_MAX := 110.0
const ROPE_REACH := 96.0      # hasta dónde llega el hilo al lanzarlo
const HANG_MAX := 7.0         # el hilo no aguanta para siempre (si no, se queda colgada fuera de alcance)
const GROUND := 128.0
const GOO := [Color("4b2b5a"), Color("2e1438"), Color("ec3949")]
const Turbo := preload("res://scripts/turbo.gd")
const WebScript := preload("res://scripts/web.gd")

var kind := "spider"
var zone := 0
var min_x := 0.0
var max_x := 99999.0
var hp := HP
var max_hp := HP
var face := -1.0
var pdir := 1.0
var cool := 1.0
var windup := 0.0   # (los héroes del bot lo miran en los hacheros)
var spit_t := -1.0
var spat := false
var stun := 0.0
var knock := 0.0
var flash := 0.0
var spawn := 0.0
var dead := false
var dead_t := 0.0
var squash := Vector2.ONE
var anim_t := 0.0
var burn_t := 0.0
var burn_k := 0.0
var parry_t := 0.0
var sprite: Sprite2D
var hurtbox: Area2D
var hero: Player
var game
var frames := {}
var villain := false
var ctrl := false
var show_hp := 0.0
var drop_t := 0.0
var charging := false
var aim_x := 0.0
# el hilo
var hanging := false
var anchor := Vector2.ZERO
var on_plat := false  # el hilo está pegado a una plataforma (si no, sube hasta las ramas, fuera de la pantalla)
var rope := 40.0
var ang := 0.0      # ángulo desde la vertical (positivo: a la derecha del enganche)
var ang_v := 0.0
var hang_t := 0.0
var rope_cd := 0.0
var shoot_line := 0.0   # el hilo recién lanzado: un destello a lo largo
var ai_rope := 4.0
var air_jump := true    # le queda el segundo salto (se recarga al pisar o al colgarse)


func _ready() -> void:
	add_to_group("enemigos")
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	floor_snap_length = 2.0
	cool = 0.8 + randf() * 1.2
	ai_rope = 3.0 + randf() * 4.0
	pdir = -1.0 if randf() < 0.5 else 1.0
	spawn = 0.55
	anim_t = randf() * 2.0
	hero = get_tree().get_first_node_in_group("heroe") as Player
	game = get_tree().get_first_node_in_group("juego")
	for anim in ["idle", "walk", "spit_g", "death_g", "hang", "spit", "death"]:
		var list: Array = []
		var i := 0
		while ResourceLoader.exists("%s%s/frame_%03d.png" % [DIR, anim, i]):
			list.append(load("%s%s/frame_%03d.png" % [DIR, anim, i]))
			i += 1
		frames[anim] = list
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 10)
	shape.shape = rect
	shape.position = Vector2(0, -5)
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture = _frame("idle", 0)
	add_child(sprite)
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 0
	hurtbox.set_collision_layer_value(4, true)
	hurtbox.collision_mask = 0
	hurtbox.set_collision_mask_value(3, true)
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(14, 11)
	hs.shape = hr
	hs.position = Vector2(0, -6)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	sprite.modulate.a = 0.0


static func asset_paths() -> Array:
	var out: Array = []
	for anim in ["idle", "walk", "spit_g", "death_g", "hang", "spit", "death"]:
		var i := 0
		while ResourceLoader.exists("%s%s/frame_%03d.png" % [DIR, anim, i]):
			out.append("%s%s/frame_%03d.png" % [DIR, anim, i])
			i += 1
	return out


func _frame(anim: String, i: int) -> Texture2D:
	var list: Array = frames.get(anim, [])
	if list.is_empty():
		return null
	return list[clampi(i, 0, list.size() - 1)]


func hit_rect() -> Rect2:
	return Rect2(global_position.x - 8, global_position.y - 13, 16, 13)


func mob_name() -> String:
	return "ARAÑA"


func mob_hint() -> String:
	if hanging:
		return "< > HAMACARSE · ARRIBA: TREPAR · SHIFT: CORTAR EL HILO · X: TELARAÑA"
	return "X: TELARAÑA · SHIFT: COLGARSE DEL HILO · DOBLE SALTO"


func _playing() -> bool:
	return game == null or game.state == "play"


func _nearest_hero() -> Player:
	var best: Player = null
	var bd := 1e9
	for h in get_tree().get_nodes_in_group("heroe"):
		var p := h as Player
		if p == null or p.dead:
			continue
		var d := absf(p.global_position.x - global_position.x) + absf(p.global_position.y - global_position.y) * 1.5
		if d < bd:
			bd = d
			best = p
	return best


func possess() -> void:
	ctrl = true
	cool = 0.0
	stun = 0.0
	flash = 0.12
	squash = Vector2(0.75, 1.35)
	if game != null:
		min_x = float(game.ZONES[zone].start + 6)
		max_x = float(game.gates[zone].x - 6) if zone < game.gates.size() else float(game.ZONES[zone].end - 6)
	var at := global_position + Vector2(0, -8)
	Fx.burst(get_parent(), at, 12, [Pal.Y, Pal.C, Pal.W], 60.0, 30.0, 0.5, 0.0)
	Fx.ring(get_parent(), at, Pal.C, 0.0, 14.0, 1.0, 0.3)


func _physics_process(dt: float) -> void:
	flash -= dt
	anim_t += dt
	shoot_line -= dt
	queue_redraw()
	if dead:
		dead_t += dt
		velocity.y = minf(velocity.y + GRAV * dt, 280.0)
		velocity.x *= maxf(0.0, 1.0 - 6.0 * dt)
		move_and_slide()
		sprite.texture = _frame("death_g", int(dead_t * 12.0))
		sprite.rotation = 0.0
		squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
		_apply_look(false)
		var hold := 1.1
		sprite.material = Fx.silhouette(Color.WHITE) if flash > 0.0 else null
		sprite.modulate = Color.WHITE if flash > 0.0 else Color(1, 1, 1, 1.0 - clampf((dead_t - hold) / 0.35, 0.0, 1.0))
		if dead_t > hold + 0.35:
			queue_free()
		return
	if spawn > 0.0:
		# baja por su hilo desde la copa de los árboles
		spawn -= dt
		var k := clampf(1.0 - spawn / 0.55, 0.0, 1.0)
		sprite.modulate.a = k
		sprite.texture = _frame("hang", int(anim_t * 10.0) % 8)
		sprite.rotation = 0.0
		_apply_look(true)
		sprite.position.y += roundf((k - 1.0) * 26.0)
		return
	if burn_t > 0.0:
		burn_t -= dt
		burn_k -= dt
		if burn_k <= 0.0:
			burn_k = 0.8
			take_hit(1, 0, "burn")
			if dead:
				return
	if parry_t > 0.0:
		parry_t -= dt
	rope_cd -= dt
	cool -= dt
	if villain:
		show_hp -= dt
		hero = _nearest_hero()
		if drop_t > 0.0:
			drop_t -= dt
			if drop_t <= 0.0:
				set_collision_mask_value(2, true)
	if hanging:
		_hang_step(dt)
	else:
		_ground_step(dt)
	_spit_step(dt)
	_touch_hero()
	_animate()


func _dev():
	return game.vdev if game != null else null


## En el piso: camina, salta y decide (vos o el juego) cuándo escupir o lanzar el hilo.
func _ground_step(dt: float) -> void:
	var dir := 0.0
	if stun > 0.0:
		stun -= dt
	elif ctrl:
		if _playing():
			dir = float(int(Ctl.down(_dev(), "derecha")) - int(Ctl.down(_dev(), "izquierda")))
			if dir != 0.0 and spit_t < 0.0:
				face = dir
			if is_on_floor():
				air_jump = true
			if Ctl.tap(_dev(), "saltar") and is_on_floor():
				if Ctl.down(_dev(), "abajo") and global_position.y < 126.0:
					set_collision_mask_value(2, false)
					drop_t = 0.25
				else:
					velocity.y = -VJUMP
					squash = Vector2(0.75, 1.3)
					Snd.play("salto", {"rate": 1.3})
			elif Ctl.tap(_dev(), "saltar") and air_jump:
				# el segundo salto, en el aire (también después de cortar el hilo)
				air_jump = false
				velocity.y = -VJUMP * 0.92
				squash = Vector2(0.7, 1.35)
				Snd.play("salto", {"rate": 1.7})
				Fx.ring(get_parent(), global_position + Vector2(0, -2), Pal.W, 0.0, 9.0, 0.6, 0.2)
				Fx.dust(get_parent(), global_position, 3, 22.0, 6.0, 1.4, Pal.S)
			if Ctl.tap(_dev(), "atacar") and cool <= 0.0:
				_start_spit()
			if Ctl.tap(_dev(), "especial") and rope_cd <= 0.0:
				_throw_rope()
				return
	else:
		dir = _think(dt)
	var top := (PSPEED if ctrl else SPEED) * (0.3 if spit_t >= 0.0 else 1.0)
	var acc := (700.0 if is_on_floor() else 450.0) * dt
	velocity.x += clampf(dir * top - velocity.x, -acc, acc)
	velocity.y = minf(velocity.y + GRAV * dt, 280.0)
	if knock != 0.0:
		velocity.x += knock
		knock *= maxf(0.0, 1.0 - 6.0 * dt)
		if absf(knock) < 6.0:
			knock = 0.0
	move_and_slide()
	if knock != 0.0:
		velocity.x -= knock
	if position.x < min_x:
		position.x = min_x
		pdir = 1.0
	elif position.x > max_x:
		position.x = max_x
		pdir = -1.0


## Manejada por el juego: se acerca hasta tener al héroe a tiro, escupe, y cada tanto se cuelga y se le tira encima.
func _think(dt: float) -> float:
	if hero == null or hero.dead:
		return 0.0
	var dx := hero.global_position.x - global_position.x
	var dy := hero.global_position.y - global_position.y
	var dist := absf(dx)
	if spit_t < 0.0:
		face = signf(dx) if dx != 0.0 else face
	ai_rope -= dt
	if cool <= 0.0 and dist < 150.0 and absf(dy) < 22.0 and is_on_floor():
		_start_spit()
		cool = 2.2 + randf() * 1.0
		Snd.play("alerta", {"rate": 1.6, "vol": 0.3})
		return 0.0
	if ai_rope <= 0.0 and dist > 40.0 and dist < 130.0 and is_on_floor() and rope_cd <= 0.0:
		ai_rope = 6.0 + randf() * 4.0
		_throw_rope()
		return 0.0
	if dist > 100.0:
		return signf(dx)
	if dist < 55.0:
		return -signf(dx)
	return 0.0


func _start_spit() -> void:
	spit_t = 0.0
	spat = false
	cool = WEB_COOL


func _spit_step(dt: float) -> void:
	if spit_t < 0.0:
		return
	spit_t += dt
	var fire := 0.2 if ctrl else 0.36
	if spit_t >= fire and not spat:
		spat = true
		var w := WebScript.new()
		w.game = game
		w.src = self
		if hanging:
			# colgada: en diagonal hacia abajo, para el lado que mira
			w.vel = Vector2(face * 130.0, 120.0)
			w.global_position = global_position + Vector2(face * 4.0, -4.0)
			ang_v -= face * 0.9  # el retroceso la hamaca
		else:
			w.vel = Vector2(face * 185.0, -18.0)
			w.global_position = global_position + Vector2(face * 11.0, -9.0)
			velocity.x -= face * 40.0
		get_parent().add_child(w)
		squash = Vector2(1.25, 0.8)
		Snd.play("baba", {"rate": 1.2, "vol": 0.7})
		Fx.twinkle(get_parent(), w.global_position, Pal.W, 3.0, 0.14)
	if spit_t >= fire + 0.3:
		spit_t = -1.0


## Lanza el hilo en diagonal (hacia arriba y adelante): se engancha en la primera plataforma que cruza o,
## si no hay, en las ramas de arriba.
func _throw_rope() -> void:
	air_jump = true
	var from := global_position + Vector2(0, -8)
	var dir := Vector2(face * 0.55, -0.84).normalized()
	var hit := from + dir * ROPE_REACH
	var plats: Array = game.PLATS if game != null else []
	var d := 12.0
	var found := false
	on_plat = false
	while d <= ROPE_REACH and not found:
		var p := from + dir * d
		if p.y < 10.0:
			hit = Vector2(p.x, 10.0)
			found = true
		for pl in plats:
			if p.x >= pl[0] and p.x <= pl[0] + pl[2] and p.y >= pl[1] and p.y <= pl[1] + 6.0:
				hit = Vector2(p.x, pl[1] + 5.0)
				found = true
				on_plat = true
				break
		d += 2.0
	anchor = hit
	hanging = true
	hang_t = 0.0
	shoot_line = 0.18
	spit_t = -1.0
	var off := (from - anchor)
	rope = clampf(off.length() - 8.0, ROPE_MIN, ROPE_MAX)   # el tirón la despega del piso
	ang = atan2(off.x, off.y)
	# arranca con el envión que traía, más un empujón hacia adelante
	ang_v = (velocity.x * cos(ang) - velocity.y * sin(ang)) / rope + face * 1.4
	velocity = Vector2.ZERO
	set_collision_mask_value(2, false)
	squash = Vector2(0.8, 1.25)
	Snd.play("disparo", {"rate": 1.7, "vol": 0.6})
	if on_plat:
		Fx.twinkle(get_parent(), anchor, Pal.W, 4.0, 0.2)
		Fx.burst(get_parent(), anchor, 6, [Pal.W, Pal.S], 50.0, 10.0, 0.3, 80.0)


## Colgada: un péndulo. Izquierda y derecha la hamacan, arriba trepa, abajo suelta hilo.
func _hang_step(dt: float) -> void:
	hang_t += dt
	var cut := hang_t > HANG_MAX
	if stun > 0.0:
		stun -= dt
	elif ctrl and _playing():
		var push := float(int(Ctl.down(_dev(), "derecha")) - int(Ctl.down(_dev(), "izquierda")))
		ang_v += push * 5.5 * dt
		if push != 0.0:
			face = push
		var climb := float(int(Ctl.down(_dev(), "abajo")) - int(Ctl.down(_dev(), "arriba")))
		if climb != 0.0:
			var was := rope
			rope = clampf(rope + climb * 46.0 * dt, ROPE_MIN, ROPE_MAX)
			if rope != was and Engine.get_physics_frames() % 6 == 0:
				Snd.play("menu", {"rate": 1.8 if climb < 0.0 else 1.2, "vol": 0.25})
		if Ctl.tap(_dev(), "atacar") and cool <= 0.0:
			_start_spit()
		if hang_t > 0.12 and (Ctl.tap(_dev(), "especial") or Ctl.tap(_dev(), "saltar")):
			cut = true
	elif not ctrl:
		# manejada por el juego: se hamaca hacia el héroe y se suelta cuando lo tiene abajo
		if hero != null and not hero.dead:
			var dx := hero.global_position.x - global_position.x
			ang_v += signf(dx) * 4.0 * dt
			face = signf(dx) if dx != 0.0 else face
			if hang_t > 0.7 and (absf(dx) < 18.0 or hang_t > 2.6):
				cut = true
	ang_v += -(GRAV / rope) * sin(ang) * dt
	ang_v *= maxf(0.0, 1.0 - 0.35 * dt)
	ang += ang_v * dt
	ang = clampf(ang, -1.05, 1.05)
	if absf(ang) >= 1.05:
		ang_v *= -0.4
	# recién enganchada recoge un poco de hilo, así se despega del piso
	if hang_t < 0.25:
		rope = maxf(ROPE_MIN, rope - 70.0 * dt)
	var want := anchor + Vector2(sin(ang), cos(ang)) * rope + Vector2(0, 8)
	# el hilo nunca la deja arrastrarse: si la hamaca la llevaría contra el piso, recoge lo que sobra
	var low := GROUND - 4.0
	if want.y > low:
		rope = maxf(ROPE_MIN, rope - (want.y - low) / maxf(0.3, cos(ang)))
		want = anchor + Vector2(sin(ang), cos(ang)) * rope + Vector2(0, 8)
	global_position = want
	if global_position.x < min_x or global_position.x > max_x:
		global_position.x = clampf(global_position.x, min_x, max_x)
		ang_v *= -0.5
	if cut:
		_cut_rope()


## Corta el hilo: sale despedida con la velocidad que llevaba en la hamaca.
func _cut_rope() -> void:
	hanging = false
	rope_cd = 0.35
	set_collision_mask_value(2, true)
	var tang := Vector2(cos(ang), -sin(ang)) * ang_v * rope
	velocity = Vector2(tang.x * 1.15, minf(tang.y * 1.15, 0.0) - 50.0).limit_length(230.0)
	sprite.rotation = 0.0
	Snd.play("tajo", {"rate": 1.8, "vol": 0.4})
	Fx.burst(get_parent(), global_position + Vector2(0, -12), 5, [Pal.W, Pal.S], 40.0, 10.0, 0.25, 100.0)
	squash = Vector2(1.2, 0.85)


func _touch_hero() -> void:
	for body in hurtbox.get_overlapping_bodies():
		var p := body as Player
		if p == null or p.dead or p.stomp_inv > 0.0:
			continue
		var top := global_position.y - 11.0
		var stomp := not hanging and p.velocity.y - velocity.y > 0.0 and p.prev_bottom <= top + 6.0
		if stomp:
			p.bounce()
			take_hit(1, 0, "stomp")
		elif parry_t <= 0.0:
			p.hurt(global_position.x, 1, self)


func parried(d: float, t: float) -> void:
	if dead or spawn > 0.0:
		return
	if hanging:
		_cut_rope()
	stun = maxf(stun, t)
	parry_t = maxf(parry_t, t)
	spit_t = -1.0
	knock = d * 135.0
	velocity.y = -150.0
	flash = 0.12


func take_hit(dmg: int, from_dir: int, how: String = "arrow") -> void:
	if dead or spawn > 0.0:
		return
	var crit := how == "riposte" or (how != "trap" and how != "poison" and how != "burn" and Fx.rand_crit())
	hp -= dmg * 3 if crit else dmg
	if crit:
		Fx.crit(get_parent(), global_position + Vector2(0, -8))
	var kd := from_dir if from_dir != 0 else (-1 if randf() < 0.5 else 1)
	if hp <= 0:
		_die(how, kd, crit)
		return
	flash = 0.12
	stun = 0.3
	spit_t = -1.0
	show_hp = 2.0
	if ctrl:
		Fx.flash_red = 0.14
		Fx.shake(3.0, 0.18)
	if hanging:
		ang_v += kd * 2.2   # el golpe la hamaca; un segundo golpe fuerte le corta el hilo
		if how == "stomp" or crit:
			_cut_rope()
	else:
		knock = kd * 100.0
		velocity.y = -90.0
	squash = Vector2(1.3, 0.75)
	Snd.play("baba", {"rate": 0.8, "vol": 0.6})
	Fx.hitstop(0.035)
	Fx.hit(get_parent(), global_position + Vector2(-kd * 3.0, -8), Vector2(kd, 0), Pal.W)
	Fx.burst(get_parent(), global_position + Vector2(0, -8), 5, GOO, 60.0, 30.0, 0.35, 260.0)
	Fx.popup(get_parent(), global_position + Vector2(0, -20), "-%d" % (dmg * 3 if crit else dmg), Pal.W)


func apply_venom() -> void:
	apply_burn()


func apply_burn(_long: bool = false, _green: bool = false) -> void:
	if dead:
		return
	burn_t = 2.4
	burn_k = 0.8


func _die(how: String, from_dir: int, crit: bool) -> void:
	if hanging:
		hanging = false
		set_collision_mask_value(2, true)
	dead = true
	dead_t = 0.0
	flash = 0.12
	velocity = Vector2(from_dir * 60.0, -120.0)
	hurtbox.set_deferred("monitoring", false)
	squash = Vector2(1.3, 0.75)
	Fx.hitstop(0.07)
	Fx.shake(2.5, 0.18)
	Snd.play("explotar", {"vol": 0.6, "rate": 1.5})
	Snd.play("baba", {"rate": 0.6, "vol": 0.8})
	var mid := global_position + Vector2(0, -8)
	Fx.ring(get_parent(), mid, Pal.W, 0.0, 14.0, 1.0, 0.25)
	Fx.burst(get_parent(), mid, 14 if crit else 10, GOO, 100.0, 50.0, 0.5, 300.0)
	Fx.hit(get_parent(), mid, Vector2(from_dir, -0.2), Pal.W, crit)
	if game != null:
		game.slime_killed(self, how, crit)


func _animate() -> void:
	if hanging:
		sprite.texture = _frame("spit", int(spit_t / 0.5 * 8.0)) if spit_t >= 0.0 else _frame("hang", int(anim_t * 10.0) % 8)
		sprite.rotation = -ang * 0.7
	else:
		sprite.rotation = 0.0
		if spit_t >= 0.0:
			sprite.texture = _frame("spit_g", int(spit_t / 0.5 * 9.0))
		elif absf(velocity.x) > 6.0 and is_on_floor():
			sprite.texture = _frame("walk", int(anim_t * 12.0) % 8)
		else:
			sprite.texture = _frame("idle", int(anim_t * 5.0) % 4)
	squash = squash.lerp(Vector2.ONE, minf(1.0, get_physics_process_delta_time() * 10.0))
	_apply_look(hanging)
	sprite.material = Fx.silhouette(Color.WHITE) if flash > 0.0 else null
	sprite.modulate = Color.WHITE if flash > 0.0 else (Color(1.35, 0.95, 0.7) if burn_t > 0.0 else Color.WHITE)


## El dibujo de costado se apoya en los pies; el de frente (colgada) gira alrededor del centro del cuerpo.
func _apply_look(front: bool) -> void:
	var sx := 0.5 * squash.x
	if front:
		sprite.offset = Vector2(-CANVAS / 2.0, -HANG_C)
		sprite.position = Vector2(0, -10)
		sprite.scale = Vector2(sx, 0.5 * squash.y)
	else:
		sprite.offset = Vector2(-CANVAS / 2.0, -FOOT_Y)
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2(sx * (1.0 if face >= 0.0 else -1.0), 0.5 * squash.y)


func _draw() -> void:
	if dead:
		return
	if spawn > 0.0:
		draw_line(Vector2(0, -150), Vector2(0, -14), Color(Pal.W, 0.7), 0.5)
		return
	if hanging:
		# el hilo, del enganche al lomo, con un nudito donde se agarra
		var a := to_local(anchor)
		var b := Vector2(0, -16)
		if on_plat:
			draw_circle(a, 1.5, Pal.W)
		else:
			# sin plataforma el hilo sigue derecho hasta perderse arriba de la pantalla: cuelga de las ramas
			a += (a - b).normalized() * 420.0
		draw_line(a, b, Pal.K, 1.5)
		draw_line(a, b, Pal.W if shoot_line > 0.0 else Pal.S, 0.5)
	if not villain:
		return
	if ctrl:
		Turbo.draw_marker(self, -30.0 if hanging else -27.0)
		if hanging:
			# cuánto le queda al hilo
			var k := clampf(1.0 - hang_t / HANG_MAX, 0.0, 1.0)
			draw_rect(Rect2(-7.5, 1.5, 15.0, 3.0), Pal.K)
			draw_rect(Rect2(-7.0, 2.0, 14.0 * k, 2.0), Pal.W if k > 0.3 or int(anim_t * 10.0) % 2 == 0 else Pal.R)
	if hp < max_hp and (show_hp > 0.0 or ctrl):
		Turbo.draw_hp(self, -24.0, hp, max_hp)
