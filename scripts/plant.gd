extends "res://scripts/forest_mob.gd"
## Planta carnívora del Bosque Oscuro. Camina muy lento sobre sus raíces.
## - ataque: no se mueve de donde está plantada: abre la boca enorme, estira el tallo y muerde allá adelante
##   (cuadros "chomp", de PixelLab); alcanza unos 40 px;
## - poder: enredaderas que avanzan por el piso en onda y pueden lastimar a varios (con recarga);
## - especial: se hunde bajo la tierra. Ahí abajo es inmune y se mueve rápido; sale sola al acabarse el
##   tiempo o al apretar el ataque, con un mordisco hacia arriba que lastima a los que tenga encima.
##   Solo se puede usar con la barra llena, y la barra se llena despacio.

const VINES_CD := 5.0
const BURROW_FILL := 8.0    # segundos para llenar la barra
const BURROW_T := 2.0       # lo que aguanta bajo tierra
const BURROW_SPEED := 96.0
const SINK := 0.22          # lo que tarda en hundirse o en salir
const BITE_REACH := 30.0    # cuánto avanza al abalanzarse
const BITE_T := 0.82        # lo que dura el mordisco entero
const SNAP_A := 0.2         # hasta acá toma carrera (se echa para atrás); después sale el latigazo
const SNAP_B := 0.39        # acá cierra la boca: el mordisco
const HOLD := 0.17          # lo que se queda clavada adelante antes de volver, rebotando
const WaveScript := preload("res://scripts/vine_wave.gd")

var bite_t := -1.0
var bit := false
var vines_t := -1.0
var cast := false
var vines_cd := 1.5
var burrow := 1.0           # la barra (0 a 1)
var under := false
var under_t := 0.0
var sink := 0.0             # 0 afuera, 1 del todo hundida
var rise_t := -1.0          # saliendo con el mordisco hacia arriba
var rose := false
var ai_burrow := 3.0


func _setup() -> void:
	kind = "plant"
	dir_path = "res://assets/sprites/bosque/planta/"
	anims = ["idle", "walk", "bite", "chomp", "vines", "death"]
	foot_y = 63.0
	draw_scale = 0.45
	body_w = 12.0
	body_h = 24.0
	base_hp = 4
	walk_speed = 13.0
	ctrl_speed = 24.0
	jump_v = 0.0
	mob_title = "PLANTA CARNÍVORA"
	goo = [Color("41ce11"), Color("189030"), Color("512c5c")]
	top_mark = -33.0


func mob_hint() -> String:
	if under:
		return "BAJO TIERRA: < > MOVERSE · X: SALIR MORDIENDO"
	return "X: MORDISCO · C: ENREDADERAS · SHIFT: HUNDIRSE (BARRA LLENA)"


func _busy() -> bool:
	return bite_t >= 0.0 or vines_t >= 0.0 or rise_t >= 0.0


func _interrupt() -> void:
	bite_t = -1.0
	vines_t = -1.0
	windup = 0.0


func _step(dt: float) -> void:
	vines_cd -= dt
	if under:
		_under_step(dt)
		return
	if rise_t < 0.0:
		burrow = minf(1.0, burrow + dt / BURROW_FILL)
		sink = maxf(0.0, sink - dt / SINK)
	var dir := 0.0
	var top := walk_speed
	if ctrl:
		dir = ctrl_dir(not _busy())
		top = ctrl_speed
		if playing() and stun <= 0.0 and not _busy():
			if Ctl.tap(dev(), "atacar") and cool <= 0.0:
				_bite(0.0)
			elif Ctl.tap(dev(), "poder") and vines_cd <= 0.0:
				_vines()
			elif Ctl.tap(dev(), "especial"):
				if burrow >= 1.0 and is_on_floor():
					_dig()
				else:
					Snd.play("menu", {"rate": 0.6, "vol": 0.4})
	elif hero != null and not hero.dead and stun <= 0.0 and not _busy():
		var dx := hero.global_position.x - global_position.x
		var dy := hero.global_position.y - global_position.y
		face = signf(dx) if dx != 0.0 else face
		ai_burrow -= dt
		if absf(dx) < 16.0 + BITE_REACH and absf(dy) < 18.0 and cool <= 0.0:
			_bite(0.3)
			cool = 1.5 + randf() * 0.6
		elif vines_cd <= 0.0 and absf(dx) < 110.0 and absf(dy) < 14.0:
			_vines()
		elif burrow >= 1.0 and ai_burrow <= 0.0 and absf(dx) > 34.0 and absf(dx) < 130.0 and is_on_floor():
			ai_burrow = 4.0 + randf() * 3.0
			_dig()
		elif absf(dx) > 30.0:
			dir = signf(dx)
	if _busy():
		dir = 0.0
	walk(dir, top, dt)
	_attacks(dt)


func _bite(wait: float) -> void:
	bite_t = 0.0
	windup = wait
	bit = false
	cool = 0.6
	if wait > 0.0:
		Snd.play("alerta", {"rate": 0.9, "vol": 0.3})


func _vines() -> void:
	vines_t = 0.0
	cast = false
	vines_cd = VINES_CD
	Snd.play("alerta", {"rate": 0.7, "vol": 0.4})


## Se hunde: desaparece bajo la tierra y pasa a moverse rápido, inmune.
func _dig() -> void:
	under = true
	under_t = 0.0
	immune = true
	burrow = 0.0
	velocity.x = 0.0
	Snd.play("explotar", {"rate": 0.5, "vol": 0.5})
	Fx.dust(get_parent(), global_position, 6, 30.0, 10.0, 2.0, Color("5a3a25"))
	Fx.burst(get_parent(), global_position, 8, [Color("5a3a25"), Color("7e5531")], 60.0, 50.0, 0.4, 300.0)


func _under_step(dt: float) -> void:
	under_t += dt
	sink = minf(1.0, sink + dt / SINK)
	var dir := 0.0
	var out := under_t >= BURROW_T
	if ctrl:
		if playing():
			dir = float(int(Ctl.down(dev(), "derecha")) - int(Ctl.down(dev(), "izquierda")))
			if dir != 0.0:
				face = dir
			if under_t > 0.25 and Ctl.tap(dev(), "atacar"):
				out = true
	elif hero != null and not hero.dead:
		# manejada por el juego: se pone debajo del héroe y sale
		var dx := hero.global_position.x - global_position.x
		dir = signf(dx) if absf(dx) > 4.0 else 0.0
		if absf(dx) <= 6.0 and under_t > 0.5:
			out = true
	var acc := 900.0 * dt
	velocity.x += clampf(dir * BURROW_SPEED - velocity.x, -acc, acc)
	velocity.y = minf(velocity.y + GRAV * dt, 280.0)
	move_and_slide()
	position.x = clampf(position.x, min_x, max_x)
	# el montoncito de tierra que la delata, y la tierra que va levantando
	if Engine.get_physics_frames() % 3 == 0:
		Fx.dust(get_parent(), global_position + Vector2(randf_range(-4, 4), 0), 1, 16.0, 5.0, 1.6, Color("5a3a25"))
	if absf(velocity.x) > 20.0 and Engine.get_physics_frames() % 5 == 0:
		Fx.part(get_parent(), global_position + Vector2(0, -1), Vector2(-face * 20.0, -40.0), 300.0, 0.3, Color("7e5531"))
	if out:
		_emerge()


## Sale de la tierra con un mordisco hacia arriba.
func _emerge() -> void:
	under = false
	rise_t = 0.0
	rose = false
	velocity.x = 0.0
	Snd.play("explotar", {"rate": 0.8, "vol": 0.7})
	Fx.shake(2.5, 0.2)
	Fx.burst(get_parent(), global_position, 14, [Color("5a3a25"), Color("7e5531"), Color("41ce11")], 110.0, 90.0, 0.5, 320.0)
	Fx.ring(get_parent(), global_position, Color("7e5531"), 0.0, 18.0, 0.4, 0.3)


func _attacks(dt: float) -> void:
	if rise_t >= 0.0:
		rise_t += dt
		sink = maxf(0.0, 1.0 - rise_t / 0.14)
		if rise_t >= 0.08 and not rose:
			rose = true
			squash = Vector2(0.7, 1.45)
			# el mordisco hacia arriba: a todos los que tenga encima, de a 2, y los tira por el aire
			var hb := Rect2(global_position.x - 11.0, global_position.y - 38.0, 22, 38)
			for p in heroes_in(hb):
				if p.hurt(global_position.x, 2, self):
					p.velocity.y = -230.0
					Fx.hitstop(0.07)
			Snd.play("tajo", {"rate": 0.6, "vol": 0.8})
		if rise_t >= 0.3:
			immune = false   # recién ahí se le puede pegar
		if rise_t >= 0.45:
			rise_t = -1.0
		return
	if windup > 0.0:
		windup -= dt
		return
	if bite_t >= 0.0:
		var was := bite_t
		bite_t += dt
		if bite_t < SNAP_A and Engine.get_physics_frames() % 3 == 0:
			# toma carrera: tiembla y junta fuerza
			Fx.part(get_parent(), global_position + Vector2(randf_range(-8, 8), -randf_range(2, 24)), Vector2(-face * 14.0, -10.0), 0.0, 0.2, Color("41ce11"))
		if was < SNAP_A and bite_t >= SNAP_A:
			Snd.play("dash", {"rate": 0.8, "vol": 0.7})
			Fx.dust(get_parent(), global_position, 5, 34.0, 8.0, 1.8, Color("5a3a25"))
		if was < SNAP_B and bite_t >= SNAP_B:
			# ¡ÑAM! cierra la boca allá adelante: muerde a todos los que estén a tiro
			var far := 12.0 + BITE_REACH
			var hb := Rect2(global_position.x + (2.0 if face > 0.0 else -far), global_position.y - 26.0, far - 2.0, 26)
			var got := false
			for p in heroes_in(hb):
				if p.hurt(global_position.x, 1, self):
					got = true
			var mouth := global_position + Vector2(face * (BITE_REACH + 6.0), -15.0)
			Snd.play("tajo", {"rate": 0.6, "vol": 0.9})
			Snd.play("clavar", {"rate": 1.4, "vol": 0.5})
			Fx.burst(get_parent(), mouth, 8, [Pal.W, Color("41ce11"), Color("863cac")], 90.0, 40.0, 0.3, 240.0)
			Fx.dust(get_parent(), global_position, 4, 34.0, 8.0, 1.8, Color("5a3a25"))
			Fx.shake(4.0 if got else 2.0, 0.18)
			Fx.hitstop(0.11 if got else 0.04)
		if bite_t >= BITE_T:
			bite_t = -1.0
	if vines_t >= 0.0:
		vines_t += dt
		if vines_t >= 0.3 and not cast:
			cast = true
			var w := WaveScript.new()
			w.dir = face
			w.src = self
			w.floor_y = global_position.y
			w.position = position + Vector2(face * 8.0, 0)
			get_parent().add_child(w)
			squash = Vector2(1.2, 0.85)
			Fx.shake(1.5, 0.12)
			Fx.dust(get_parent(), global_position + Vector2(face * 8.0, 0), 4, 26.0, 8.0, 1.8, Color("5a3a25"))
		if vines_t >= 0.6:
			vines_t = -1.0


func _anim() -> void:
	touch = not under and rise_t < 0.0
	if rise_t >= 0.0:
		sprite.texture = frame("bite", 3 + int(rise_t / 0.45 * 5.0))
	elif windup > 0.0:
		sprite.texture = frame("chomp", 0 if int(anim_t * 14.0) % 2 == 0 else 7)   # avisa: abre y cierra la boca
	elif bite_t >= 0.0:
		# los cuadros de "chomp" (128 de ancho, la planta a la izquierda): abre la boca enorme, sale el tallo
		# estirado, cierra de golpe allá adelante y vuelve
		if bite_t < SNAP_A:
			sprite.texture = frame("chomp", 0)
		elif bite_t < SNAP_B:
			# sale el tallo y la boca se abre cada vez más; el último cuadro, ya cerrando, apenas se ve
			var k := (bite_t - SNAP_A) / (SNAP_B - SNAP_A)
			sprite.texture = frame("chomp", 1 if k < 0.2 else (2 if k < 0.4 else (3 if k < 0.86 else 4)))
		elif bite_t < SNAP_B + HOLD:
			sprite.texture = frame("chomp", 5)
		else:
			sprite.texture = frame("chomp", 6 if bite_t < SNAP_B + HOLD + 0.08 else 7)
	elif vines_t >= 0.0:
		sprite.texture = frame("vines", int(vines_t / 0.6 * count("vines")))
	elif absf(velocity.x) > 3.0 and is_on_floor():
		sprite.texture = frame("walk", int(anim_t * 9.0) % count("walk"))
	else:
		sprite.texture = frame("idle", int(anim_t * 5.0) % count("idle"))


## Hundida se recorta contra el piso: el dibujo baja y se le corta lo que queda bajo tierra.
## Al salir con el mordisco hacia arriba, el dibujo se estira para arriba.
func look() -> void:
	super.look()
	var h := canvas * (1.0 - sink * 0.97)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, sprite.texture.get_width() if sprite.texture != null else canvas, h)
	sprite.offset = Vector2(-canvas / 2.0, -foot_y)
	sprite.position.y = roundf(sink * foot_y * draw_scale)
	sprite.rotation = (-0.5 * face if faces_right else 0.5 * face) * clampf(1.0 - absf(rise_t - 0.1) / 0.2, 0.0, 1.0) if rise_t >= 0.0 else 0.0
	# el mordisco: junta fuerza achatándose y al morder tiembla un poco (el estirón ya viene dibujado)
	if windup > 0.0 or (bite_t >= 0.0 and bite_t < SNAP_A):
		sprite.scale *= Vector2(1.1, 0.86 + 0.03 * sin(anim_t * 60.0))
	elif bite_t >= SNAP_A and bite_t < SNAP_B:
		# con la boca abierta se agranda y se estira todavía más de lo que está dibujada
		var k := clampf((bite_t - SNAP_A) / 0.08, 0.0, 1.0)
		sprite.scale *= Vector2(1.0 + 0.28 * k, 1.0 + 0.18 * k)
	elif bite_t >= SNAP_B and bite_t < SNAP_B + HOLD:
		# el ñam: se aplasta de golpe y tiembla
		var u := (bite_t - SNAP_B) / HOLD
		sprite.scale *= Vector2(1.28 - 0.1 * u, 0.78 + 0.22 * u)
		sprite.position.y += roundf(sin(anim_t * 90.0) * (1.0 - u) * 1.5)


func _draw() -> void:
	if dead or spawn > 0.0:
		return
	if under:
		# el montículo
		draw_circle(Vector2(0, 0), 4.0, Color("5a3a25"))
		draw_rect(Rect2(-5, 0, 10, 2), Color("5a3a25"))
		draw_rect(Rect2(-1, -5, 2, 2), Color("41ce11"))
	if not villain:
		return
	if ctrl:
		if under:
			Turbo.draw_marker(self, -12.0)
			draw_meter(1.0 - under_t / BURROW_T, 6.0, Color("7e5531"))
		else:
			Turbo.draw_marker(self, top_mark)
			draw_meter(burrow, 2.0, Color("7e5531"))   # la barra de hundirse
			if vines_cd > 0.0:
				draw_meter(1.0 - vines_cd / VINES_CD, 6.0, Color("41ce11"))
	if hp < max_hp and (show_hp > 0.0 or ctrl) and not immune:
		Turbo.draw_hp(self, top_mark + 4.0, hp, max_hp)
