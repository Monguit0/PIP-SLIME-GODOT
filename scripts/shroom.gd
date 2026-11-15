extends "res://scripts/forest_mob.gd"
## Hongo esporero del Bosque Oscuro. Lento y aguantador.
## - ataque: un puñetazo corto;
## - poder: invoca dos mini hongos que corren por el piso (recarga larga, para no llenar la pantalla);
## - especial: el turbo de siempre;
## - al morir revienta (no queda cuerpo) y deja una nube venenosa grande que lastima al que se queda adentro.

const SUMMON_CD := 6.0
const MiniScript := preload("res://scripts/mini_shroom.gd")
const CloudScript := preload("res://scripts/spore_cloud.gd")

var punch_t := -1.0
var punched := false
var summon_t := -1.0
var summoned := false
var summon_cd := 2.0


func _setup() -> void:
	kind = "shroom"
	dir_path = "res://assets/sprites/bosque/hongo/"
	anims = ["idle", "walk", "punch", "summon", "death"]
	foot_y = 62.0
	draw_scale = 0.42
	body_w = 12.0
	body_h = 22.0
	base_hp = 8
	vanish = true
	walk_speed = 24.0
	ctrl_speed = 46.0
	jump_v = 215.0
	mob_title = "HONGO ESPORERO"
	goo = [Color("863cac"), Color("e6d9c8"), Pal.L]
	top_mark = -31.0


func mob_hint() -> String:
	return "X: PUÑETAZO · C: MINI HONGOS · SHIFT: TURBO"


func _busy() -> bool:
	return punch_t >= 0.0 or summon_t >= 0.0


func _interrupt() -> void:
	punch_t = -1.0
	summon_t = -1.0
	windup = 0.0


func _step(dt: float) -> void:
	summon_cd -= dt
	var dir := 0.0
	var top := walk_speed
	if ctrl:
		dir = ctrl_dir(not _busy())
		var on: bool = turbo.step(self, dt, stun <= 0.0 and Ctl.down(dev(), "especial") and playing() and not _busy(), face, Color("863cac"), 9.0)
		top = ctrl_speed * (Turbo.MUL if on else 1.0)
		if playing() and stun <= 0.0 and not _busy():
			if Ctl.tap(dev(), "atacar") and cool <= 0.0:
				_punch(0.0)
			elif Ctl.tap(dev(), "poder") and summon_cd <= 0.0:
				_summon()
	elif hero != null and not hero.dead and stun <= 0.0 and not _busy():
		var dx := hero.global_position.x - global_position.x
		var dy := hero.global_position.y - global_position.y
		face = signf(dx) if dx != 0.0 else face
		if absf(dx) < 20.0 and absf(dy) < 16.0 and cool <= 0.0:
			_punch(0.22)
			cool = 1.4 + randf() * 0.6
		elif summon_cd <= 0.0 and absf(dx) < 150.0 and is_on_floor():
			_summon()
		elif absf(dx) > 16.0:
			dir = signf(dx)
	if _busy():
		dir = 0.0
	walk(dir, top, dt)
	_attacks(dt)


## wait: lo que tarda en salir el golpe además del gesto (el aviso, cuando lo maneja el juego)
func _punch(wait: float) -> void:
	punch_t = -wait if wait > 0.0 else 0.0
	windup = wait
	punched = false
	cool = 0.55
	if wait > 0.0:
		punch_t = 0.0
		Snd.play("alerta", {"rate": 0.8, "vol": 0.3})


func _summon() -> void:
	summon_t = 0.0
	summoned = false
	summon_cd = SUMMON_CD
	Snd.play("alerta", {"rate": 0.6, "vol": 0.4})


func _attacks(dt: float) -> void:
	if windup > 0.0:
		windup -= dt
		return
	if punch_t >= 0.0:
		punch_t += dt
		if punch_t >= 0.26 and not punched:
			punched = true
			velocity.x += face * 60.0
			squash = Vector2(1.25, 0.82)
			Snd.play("tajo", {"rate": 0.8, "vol": 0.7})
			var hb := Rect2(global_position.x + (2.0 if face > 0.0 else -24.0), global_position.y - 20.0, 22, 18)
			Fx.slash(get_parent(), global_position + Vector2(face * 12.0, -12), 9.0, -50.0, 50.0, face, Pal.W, 2.0, 0.1)
			for p in heroes_in(hb):
				if p.hurt(global_position.x, 1, self):
					Fx.hitstop(0.05)
		if punch_t >= 0.55:
			punch_t = -1.0
	if summon_t >= 0.0:
		summon_t += dt
		if Engine.get_physics_frames() % 4 == 0:
			Fx.part(get_parent(), global_position + Vector2(randf_range(-8, 8), -randf_range(16, 26)), Vector2(0, -20), 0.0, 0.3, Pal.L)
		if summon_t >= 0.45 and not summoned:
			summoned = true
			for s in [-1.0, 1.0]:
				var m := MiniScript.new()
				m.zone = zone
				m.min_x = min_x
				m.max_x = max_x
				m.face = s
				m.position = position + Vector2(s * 9.0, -2.0)
				m.velocity.x = s * 40.0
				get_parent().add_child(m)
			squash = Vector2(1.2, 0.85)
			Snd.play("hechizo", {"rate": 1.3, "vol": 0.6})
			Fx.ring(get_parent(), global_position + Vector2(0, -4), Pal.L, 0.0, 16.0, 0.5, 0.3)
		if summon_t >= 0.75:
			summon_t = -1.0


func _anim() -> void:
	if windup > 0.0:
		sprite.texture = frame("punch", 1 + int(anim_t * 14.0) % 2)   # toma carrera
	elif punch_t >= 0.0:
		sprite.texture = frame("punch", int(punch_t / 0.55 * count("punch")))
	elif summon_t >= 0.0:
		sprite.texture = frame("summon", int(summon_t / 0.75 * count("summon")))
	elif absf(velocity.x) > 5.0 and is_on_floor():
		sprite.texture = frame("walk", int(anim_t * (14.0 if turbo.on else 9.0)) % count("walk"))
	else:
		sprite.texture = frame("idle", int(anim_t * 5.0) % count("idle"))


func _on_death(_how: String, _from_dir: int) -> void:
	# revienta: no queda cuerpo, queda la nube
	var c := CloudScript.new()
	c.position = position
	get_parent().add_child(c)
	var mid := global_position + Vector2(0, -12)
	Fx.shake(4.0, 0.28)
	Fx.hitstop(0.09)
	Fx.ring(get_parent(), mid, Color("9ffd4e"), 4.0, 40.0, 1.0, 0.35)
	Fx.ring(get_parent(), mid, Pal.W, 0.0, 24.0, 1.0, 0.2)
	Fx.burst(get_parent(), mid, 18, [Color("863cac"), Color("e6d9c8"), Color("29da0c")], 150.0, 90.0, 0.6, 320.0)
	Fx.burst(get_parent(), mid, 12, [Color("9ffd4e"), Color("29da0c")], 70.0, 20.0, 0.9, -30.0)


func _draw_extra() -> void:
	if ctrl:
		turbo.draw_bar(self)
		# los mini hongos: una barrita que se llena mientras recargan
		if summon_cd > 0.0:
			draw_meter(1.0 - summon_cd / SUMMON_CD, 6.0, Pal.L)
