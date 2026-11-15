extends "res://scripts/forest_mob.gd"
## Hongo boxeador: minijefe del Bosque Oscuro. Aguanta mucho (HP), no lo frena cada golpe y tiene cuatro
## movimientos:
## - atacar: uno-dos (jab y cruzado);
## - poder: puño del dragón, un uppercut que lo levanta del piso y revolea a los que agarra (con recarga);
## - especial: esquive, un paso rápido durante el que no le entra nada (con recarga);
## - abajo + atacar: se cubre bajo el sombrero (no le entra nada; si le pegan, carga el golpe) y contesta
##   con un puñetazo enorme que lo impulsa hacia adelante y saca mucho (con recarga).

const HP := 20
const COMBO_T := 0.6
const JAB_AT := 0.17
const CROSS_AT := 0.36
const DP_CD := 3.0
const DP_VY := 310.0
const DODGE_CD := 1.4
const DODGE_T := 0.3
const DODGE_SPD := 170.0
const COUNTER_CD := 4.0
const COVER_T := 0.5        # lo que se queda cubierto antes de soltar el golpe
const PUNCH_T := 0.5
const PUNCH_AT := 0.1
const PUNCH_DMG := 3        # el gran puñetazo (4 si antes le pegaron estando cubierto)

var miniboss := true
var combo_t := -1.0
var jabbed := false
var crossed := false
var dp_t := -1.0
var dp_cd := 1.5
var dp_hit: Array = []
var dp_land := 0.0
var dodge_t := -1.0
var dodge_cd := 0.0
var dodge_dir := 1.0
var cover_t := -1.0
var charged := false
var punch_t := -1.0
var punched := false
var counter_cd := 2.0
var ai_dodge := false       # le acaban de pegar: capaz esquiva
var hurt_show := 0.0


func _setup() -> void:
	kind = "boxer"
	dir_path = "res://assets/sprites/bosque/boxeador/"
	anims = ["idle", "walk", "hurt", "dodge", "death", "combo", "dragon", "counter"]
	foot_y = 62.0
	draw_scale = 0.6
	body_w = 14.0
	body_h = 32.0
	base_hp = HP
	walk_speed = 36.0
	ctrl_speed = 60.0
	jump_v = 240.0
	mob_title = "HONGO BOXEADOR"
	goo = [Color("583e64"), Color("108b89"), Color("20efe9")]
	top_mark = -44.0


func mob_hint() -> String:
	return "X: UNO-DOS · C: PUÑO DEL DRAGÓN · SHIFT: ESQUIVE · ABAJO + X: CUBRIRSE Y GRAN PUÑETAZO"


func _busy() -> bool:
	return combo_t >= 0.0 or dp_t >= 0.0 or dodge_t >= 0.0 or cover_t >= 0.0 or punch_t >= 0.0 or dp_land > 0.0


func _interrupt() -> void:
	combo_t = -1.0
	dp_t = -1.0
	dodge_t = -1.0
	cover_t = -1.0
	punch_t = -1.0
	windup = 0.0
	immune = false


## Es un minijefe: los golpes no le cortan lo que está haciendo (el parry sí). Cubierto, no le entra nada y
## el golpe que recibe le carga el puñetazo.
func take_hit(dmg: int, from_dir: int, how: String = "arrow") -> void:
	if dead or spawn > 0.0 or immune:
		return
	if cover_t >= 0.0:
		charged = true
		flash = 0.1
		if from_dir != 0:
			face = -float(from_dir)
		cover_t = maxf(cover_t, COVER_T - 0.06)   # contesta ya
		Snd.play("escudo", {"rate": 0.8, "vol": 0.8})
		Fx.popup(get_parent(), global_position + Vector2(0, -44), "¡BLOQUEO!", Pal.C)
		Fx.burst(get_parent(), global_position + Vector2(-face * -6.0, -22), 6, [Pal.W, Pal.C], 70.0, 20.0, 0.25, 100.0)
		return
	var keep := [combo_t, dp_t, punch_t, jabbed, crossed, punched, velocity]
	var busy := _busy()
	super.take_hit(dmg, from_dir, how)
	if dead:
		return
	hurt_show = 0.18
	if busy:
		combo_t = keep[0]
		dp_t = keep[1]
		punch_t = keep[2]
		jabbed = keep[3]
		crossed = keep[4]
		punched = keep[5]
		velocity = keep[6]
		stun = 0.0
		knock = 0.0
	else:
		stun = 0.14
		knock *= 0.4
		ai_dodge = randf() < 0.5


func _step(dt: float) -> void:
	dp_cd -= dt
	dodge_cd -= dt
	counter_cd -= dt
	hurt_show -= dt
	var dir := 0.0
	var top := walk_speed
	if ctrl:
		top = ctrl_speed
		if not _busy():
			dir = ctrl_dir()
			if playing() and stun <= 0.0:
				if Ctl.tap(dev(), "atacar"):
					if Ctl.down(dev(), "abajo"):
						if counter_cd <= 0.0:
							_cover()
						else:
							Snd.play("menu", {"rate": 0.6, "vol": 0.4})
					elif cool <= 0.0:
						_combo(0.0)
				elif Ctl.tap(dev(), "poder"):
					if dp_cd <= 0.0:
						_dragon()
					else:
						Snd.play("menu", {"rate": 0.6, "vol": 0.4})
				elif Ctl.tap(dev(), "especial") and dodge_cd <= 0.0:
					_dodge(dir if dir != 0.0 else -face)
	elif hero != null and not hero.dead and stun <= 0.0 and not _busy():
		var dx := hero.global_position.x - global_position.x
		var dy := hero.global_position.y - global_position.y
		face = signf(dx) if dx != 0.0 else face
		if ai_dodge and dodge_cd <= 0.0:
			ai_dodge = false
			_dodge(-face if absf(dx) < 30.0 else face)
		elif dp_cd <= 0.0 and dy < -12.0 and absf(dx) < 26.0:
			_dragon()
		elif absf(dx) < 26.0 and absf(dy) < 22.0 and cool <= 0.0:
			cool = 0.9 + randf() * 0.5
			if counter_cd <= 0.0 and randf() < 0.4:
				_cover()
			else:
				_combo(0.16)
		elif counter_cd <= 0.0 and absf(dx) > 34.0 and absf(dx) < 70.0 and absf(dy) < 22.0 and randf() < dt * 1.2:
			_cover()
		elif absf(dx) > 20.0:
			dir = signf(dx)
		ai_dodge = false
	# --- lo que está haciendo ---
	if windup > 0.0:
		windup -= dt
	elif combo_t >= 0.0:
		combo_t += dt
		if combo_t >= JAB_AT and not jabbed:
			jabbed = true
			_punch_hit(22.0, 1, Vector2(face * 60.0, -40.0), 0.04, 1.5)
			velocity.x += face * 50.0
			Snd.play("tajo", {"rate": 1.5, "vol": 0.5})
		if combo_t >= CROSS_AT and not crossed:
			crossed = true
			_punch_hit(26.0, 1, Vector2(face * 150.0, -90.0), 0.07, 3.0)
			velocity.x += face * 70.0
			squash = Vector2(1.2, 0.88)
			Snd.play("tajo", {"rate": 0.9, "vol": 0.8})
		if combo_t >= COMBO_T:
			combo_t = -1.0
	elif dp_t >= 0.0:
		dp_t += dt
		dir = face * 0.6
		top = 70.0
		immune = dp_t < 0.2          # arranca invulnerable
		if dp_t < 0.42:
			# mientras sube: a cada héroe que agarra, una vez, y lo revolea para arriba
			var hb := Rect2(global_position.x - 13.0 + face * 6.0, global_position.y - 46.0, 26, 42)
			for p in heroes_in(hb):
				if dp_hit.has(p):
					continue
				dp_hit.append(p)
				if p.hurt(global_position.x - face * 4.0, 2, self):
					p.velocity = Vector2(face * 60.0, -300.0)
					Fx.hitstop(0.1)
					Fx.shake(4.0, 0.2)
					Snd.boom(0.6)
					Fx.burst(get_parent(), p.global_position + Vector2(0, -10), 10, [Pal.W, Color("20efe9"), Pal.Y], 110.0, 80.0, 0.4, 240.0)
			if Engine.get_physics_frames() % 2 == 0:
				Fx.part(get_parent(), global_position + Vector2(face * 6.0, -randf_range(20, 44)), Vector2(-face * 20.0, 30.0), 0.0, 0.25, Color("20efe9") if randf() < 0.6 else Pal.W)
		if dp_t > 0.25 and is_on_floor() and velocity.y >= 0.0:
			dp_t = -1.0
			dp_land = 0.22
			immune = false
			squash = Vector2(1.3, 0.75)
			Fx.dust(get_parent(), global_position, 5, 34.0, 6.0, 1.8, Pal.S)
	elif dp_land > 0.0:
		dp_land -= dt
	elif dodge_t >= 0.0:
		dodge_t += dt
		immune = true
		velocity.x = dodge_dir * DODGE_SPD
		if Engine.get_physics_frames() % 3 == 0:
			Fx.part(get_parent(), global_position + Vector2(0, -randf_range(6, 30)), Vector2(-dodge_dir * 20.0, 0), 0.0, 0.2, Color("108b89"))
		if dodge_t >= DODGE_T:
			dodge_t = -1.0
			immune = false
			velocity.x = 0.0
	elif cover_t >= 0.0:
		cover_t += dt
		if charged and Engine.get_physics_frames() % 2 == 0:
			Fx.part(get_parent(), global_position + Vector2(randf_range(-10, 10), -randf_range(4, 34)), Vector2(0, -30), 0.0, 0.25, Pal.Y if randf() < 0.5 else Color("20efe9"))
		if cover_t >= COVER_T:
			cover_t = -1.0
			punch_t = 0.0
			punched = false
			# el impulso: se tira hacia adelante con todo el cuerpo
			velocity.x = face * 230.0
			squash = Vector2(1.35, 0.8)
			Snd.play("dash", {"rate": 0.7, "vol": 0.8})
			Fx.dust(get_parent(), global_position, 5, 36.0, 6.0, 1.8, Pal.S)
	elif punch_t >= 0.0:
		punch_t += dt
		if punch_t < PUNCH_AT + 0.05:
			dir = face
			top = 230.0
		if punch_t >= PUNCH_AT and not punched:
			punched = true
			var dmg := PUNCH_DMG + (1 if charged else 0)
			var got := _punch_hit(40.0, dmg, Vector2(face * 260.0, -170.0), 0.14, 6.0)
			Snd.play("tajo", {"rate": 0.5, "vol": 1.0})
			Snd.boom(0.9 if got else 0.5)
			Fx.kick(Vector2(face, 0), 3.0)
			if got:
				Fx.popup(get_parent(), global_position + Vector2(face * 30.0, -40), "¡PUM!", Pal.Y, true)
			charged = false
		if punch_t >= PUNCH_T:
			punch_t = -1.0
	if _busy() and dp_t < 0.0 and not (punch_t >= 0.0 and punch_t < PUNCH_AT + 0.05):
		dir = 0.0
	walk(dir, top, dt)


## Un golpe hacia adelante: lastima a los héroes hasta `reach` px, los empuja y devuelve si acertó.
func _punch_hit(reach: float, dmg: int, push: Vector2, stop: float, shk: float) -> bool:
	var hb := Rect2(global_position.x + (2.0 if face > 0.0 else -reach), global_position.y - 34.0, reach - 2.0, 32)
	var got := false
	for p in heroes_in(hb):
		if p.hurt(global_position.x, dmg, self):
			got = true
			p.velocity = push
			Fx.burst(get_parent(), p.global_position + Vector2(0, -10), 6 + dmg * 2, [Pal.W, Pal.Y, Color("20efe9")], 90.0 + dmg * 20.0, 40.0, 0.3, 240.0)
	if got:
		Fx.hitstop(stop)
		Fx.shake(shk, 0.1 + shk * 0.03)
	return got


func _combo(wait: float) -> void:
	combo_t = 0.0
	windup = wait
	jabbed = false
	crossed = false
	cool = 0.5
	if wait > 0.0:
		Snd.play("alerta", {"rate": 1.1, "vol": 0.25})


func _dragon() -> void:
	dp_t = 0.0
	dp_cd = DP_CD
	dp_hit.clear()
	velocity = Vector2(face * 50.0, -DP_VY)
	squash = Vector2(0.75, 1.35)
	Snd.play("salto", {"rate": 0.8, "vol": 0.8})
	Snd.play("fuego", {"rate": 1.4, "vol": 0.5})
	Fx.dust(get_parent(), global_position, 6, 40.0, 8.0, 2.0, Pal.S)
	Fx.shake(1.5, 0.12)


func _dodge(d: float) -> void:
	dodge_t = 0.0
	dodge_cd = DODGE_CD
	dodge_dir = signf(d) if d != 0.0 else -face
	Snd.play("dash", {"rate": 1.3, "vol": 0.5})


func _cover() -> void:
	cover_t = 0.0
	charged = false
	counter_cd = COUNTER_CD
	Snd.play("escudo", {"rate": 1.2, "vol": 0.5})


func _anim() -> void:
	if dodge_t >= 0.0:
		sprite.texture = frame("dodge", 1 + int(dodge_t / DODGE_T * 5.0))
	elif cover_t >= 0.0:
		sprite.texture = frame("counter", 2 if cover_t < 0.06 else (3 + int(anim_t * 10.0) % 2))
	elif punch_t >= 0.0:
		sprite.texture = frame("counter", 6 if punch_t < PUNCH_AT else clampi(7 + int((punch_t - PUNCH_AT) / 0.09), 7, 10))
	elif dp_t >= 0.0:
		var n := count("dragon")
		# sube (cuadros del medio), llega arriba y cae
		var k := clampf(dp_t / 0.55, 0.0, 1.0)
		sprite.texture = frame("dragon", 1 + int(k * (n - 3)))
	elif dp_land > 0.0:
		sprite.texture = frame("dragon", count("dragon") - 1)
	elif windup > 0.0:
		sprite.texture = frame("combo", 1)
	elif combo_t >= 0.0:
		sprite.texture = frame("combo", 2 + int(combo_t / COMBO_T * 10.0))
	elif hurt_show > 0.0 or stun > 0.0:
		sprite.texture = frame("hurt", 1)
	elif absf(velocity.x) > 5.0 and is_on_floor():
		sprite.texture = frame("walk", int(anim_t * 10.0) % count("walk"))
	else:
		sprite.texture = frame("idle", int(anim_t * 8.0) % count("idle"))


func look() -> void:
	super.look()
	# los cuadros del puño del dragón son más altos (64x128): los pies siguen abajo
	var th: float = sprite.texture.get_height() if sprite.texture != null else canvas
	sprite.offset.y = -(foot_y + th - canvas)
	sprite.modulate.a = 0.6 if dodge_t >= 0.0 else sprite.modulate.a
	if cover_t >= 0.0:
		sprite.scale *= Vector2(1.06, 0.94 + 0.02 * sin(anim_t * 60.0))
	elif punch_t >= 0.0 and punch_t < 0.2:
		sprite.scale *= Vector2(1.2, 0.95)


func _draw() -> void:
	super._draw()
	if dead or spawn > 0.0:
		return
	if not villain:
		# minijefe: la vida siempre a la vista, en una barra más ancha
		draw_rect(Rect2(-13.5, top_mark - 0.5, 27.0, 4.0), Pal.K)
		draw_rect(Rect2(-13.0, top_mark, 26.0 * hp / float(max_hp), 3.0), Pal.R)
	if ctrl:
		# recargas: puño del dragón, esquive y contragolpe
		if dp_cd > 0.0:
			draw_meter(1.0 - dp_cd / DP_CD, 2.0, Color("20efe9"))
		if counter_cd > 0.0:
			draw_meter(1.0 - counter_cd / COUNTER_CD, 6.0, Pal.Y)
		if dodge_cd > 0.0:
			draw_meter(1.0 - dodge_cd / DODGE_CD, 10.0, Color("108b89"))
