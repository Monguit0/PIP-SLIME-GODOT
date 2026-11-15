extends "res://scripts/forest_mob.gd"
## Murciélago del Bosque Oscuro (el del juego web): revolotea arriba del héroe y cada tanto baja en picada.
## No camina: vuela, atraviesa las plataformas y no le afecta la gravedad hasta que lo matan.
## Manejado por una persona (modo Villano): las flechas lo vuelan y X lo tira en picada hacia donde mira.

const SPD := 62.0
const DIVE_SPD := 165.0
const DIVE_T := 0.7
const WARN := 0.28          # el aviso antes de la picada

var t2 := 0.0
var dive := 0.0
var warn := 0.0
var aim := Vector2.ZERO
var lifted := false


func _setup() -> void:
	kind = "bat"
	dir_path = "res://assets/sprites/bosque/murcielago/"
	anims = ["fly", "dive", "death"]
	idle_anim = "fly"
	foot_y = 36.0
	draw_scale = 0.36
	body_w = 12.0
	body_h = 10.0
	base_hp = 1
	mob_title = "MURCIÉLAGO"
	goo = [Color("5e3662"), Color("362852"), Pal.R]
	top_mark = -20.0
	t2 = randf() * 6.0


func mob_hint() -> String:
	return "FLECHAS: VOLAR · X: PICADA"


func _step(dt: float) -> void:
	if not lifted:
		# aparece en el aire
		lifted = true
		position.y = minf(position.y, GROUND) - 34.0
	t2 += dt
	var want := Vector2.ZERO
	var spd := SPD
	if stun > 0.0:
		stun -= dt
		want = Vector2(0, 1)
		spd = 30.0
		dive = 0.0
		warn = 0.0
	elif warn > 0.0:
		# avisa: se frena, tiembla y chilla
		warn -= dt
		spd = 0.0
		if warn <= 0.0:
			dive = DIVE_T
			Snd.play("dash", {"rate": 1.6, "vol": 0.4})
	elif dive > 0.0:
		dive -= dt
		want = aim - global_position
		spd = DIVE_SPD
		if want.length() < 6.0:
			dive = 0.0
		if Engine.get_physics_frames() % 2 == 0:
			Fx.part(get_parent(), global_position + Vector2(0, -6), -velocity * 0.1, 0.0, 0.2, Color("885686"))
	elif ctrl:
		if playing():
			want = Vector2(float(int(Ctl.down(dev(), "derecha")) - int(Ctl.down(dev(), "izquierda"))), float(int(Ctl.down(dev(), "abajo")) - int(Ctl.down(dev(), "arriba"))))
			spd = 84.0
			if want.x != 0.0:
				face = signf(want.x)
			if Ctl.tap(dev(), "atacar") and cool <= 0.0:
				cool = 0.9
				dive = 0.45
				aim = global_position + Vector2(face * 52.0, 44.0)
				aim.y = minf(aim.y, GROUND - 2.0)
				Snd.play("dash", {"rate": 1.6, "vol": 0.4})
	elif hero != null and not hero.dead:
		var hp := hero.global_position
		want = Vector2(hp.x + sin(t2 * 1.3) * 34.0, hp.y - 34.0 + sin(t2 * 3.0) * 4.0) - global_position
		if want.length() < 3.0:
			want = Vector2.ZERO
		if cool <= 0.0 and absf(hp.x - global_position.x) < 40.0 and hp.y > global_position.y:
			warn = WARN
			aim = hp + Vector2(0, -4.0)
			cool = 2.2 + randf() * 1.5
			face = signf(hp.x - global_position.x) if hp.x != global_position.x else face
			Snd.play("alerta", {"rate": 1.8, "vol": 0.3})
	var v := want.normalized() * spd if want != Vector2.ZERO else Vector2.ZERO
	velocity += (v - velocity) * minf(1.0, dt * (9.0 if dive > 0.0 else 4.0))
	if knock != 0.0:
		velocity.x += knock * dt * 8.0
		knock *= maxf(0.0, 1.0 - 6.0 * dt)
		if absf(knock) < 6.0:
			knock = 0.0
	position += velocity * dt
	position.x = clampf(position.x, min_x, max_x)
	position.y = clampf(position.y, 14.0, GROUND - 1.0)
	if dive <= 0.0 and warn <= 0.0 and absf(velocity.x) > 8.0 and not ctrl:
		face = signf(velocity.x)


func _anim() -> void:
	if dive > 0.0:
		sprite.texture = frame("dive", 2 + int(anim_t * 14.0) % 3)
	elif warn > 0.0:
		sprite.texture = frame("dive", 0 if warn > WARN * 0.5 else 1)
	else:
		sprite.texture = frame("fly", int(anim_t * 14.0) % count("fly"))


func look() -> void:
	super.look()
	sprite.position.x = roundf(sin(anim_t * 70.0)) if warn > 0.0 else 0.0
	sprite.rotation = clampf(velocity.y / 260.0, -0.5, 0.9) * (1.0 if face >= 0.0 else -1.0) if not dead else 0.0
