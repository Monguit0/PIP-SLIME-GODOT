extends CharacterBody2D
## Esqueletos aliados del Nigromante (summonSkeletons y updateAllies del original): salen de la tierra
## a sus costados, buscan al enemigo más cercano (el de hacha va al cuerpo a cuerpo, el de arco guarda
## distancia y dispara), lo siguen entre zonas y duran 12 segundos o hasta que los rompan (2 golpes).
## Pegan de a 1. Son los mismos cuadros de los esqueletos del castillo, con el brillo verde de las almas.

const GRAV := 900.0
const DIR := "res://assets/sprites/skel/"
const CANVAS := 68.0
const FOOT_Y := 57.0
const LIFE := 12.0
const HP := 2
const SPEED := 54.0
const EnemyArrow := preload("res://scripts/enemy_arrow.gd")
const BONE := [Color("e0d7b9"), Color("b5a98d"), Pal.S]
const SOUL := Color(0.72, 1.3, 0.8)

var kind := "skaxe"
var owner_hero: Player
var game
var face := 1.0
var hp := HP
var life := LIFE
var rise := 0.55
var cool := 0.5
var inv := 0.0
var flash := 0.0
var windup := 0.0
var swing_t := 9.0
var swing_hit := false
var shoot_t := -1.0
var shot := false
var knock := 0.0
var dead := false
var dead_t := 0.0
var anim_t := 0.0
var squash := Vector2.ONE
var sprite: Sprite2D
var frames := {}


func _ready() -> void:
	add_to_group("aliados")
	z_index = 1
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	floor_snap_length = 2.0
	var folder := DIR + ("arch" if kind == "skarch" else "axe") + "/"
	for anim in ["idle", "walk", "atk", "hurt", "death"]:
		var list: Array = []
		var i := 0
		while ResourceLoader.exists("%s%s/frame_%03d.png" % [folder, anim, i]):
			list.append(load("%s%s/frame_%03d.png" % [folder, anim, i]))
			i += 1
		frames[anim] = list
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 18)
	shape.shape = rect
	shape.position = Vector2(0, -9)
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-CANVAS / 2.0, -FOOT_Y)
	sprite.texture = _frame("idle", 0)
	sprite.modulate = Color(SOUL, 0.0)
	add_child(sprite)
	anim_t = randf() * 2.0


func _frame(anim: String, i: int) -> Texture2D:
	var list: Array = frames.get(anim, [])
	if list.is_empty():
		list = frames.get("idle", [])
	if list.is_empty():
		return null
	return list[clampi(i, 0, list.size() - 1)]


func hit_rect() -> Rect2:
	return Rect2(global_position.x - 4, global_position.y - 18, 8, 18)


## el enemigo más cercano que pueda alcanzar: {pos, node} o {} si no hay; el jefe cuenta
func _target() -> Dictionary:
	var best := {}
	var bd := 170.0
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.dead or e.spawn > 0.0 or not e.has_method("hit_rect"):
			continue
		var d: Vector2 = e.global_position - global_position
		if absf(d.y) > 34.0 or absf(d.x) > bd:
			continue
		bd = absf(d.x)
		best = {"pos": e.global_position, "node": e}
	var b = game.boss if game != null else null
	if best.is_empty() and b != null and is_instance_valid(b) and b.active():
		var r: Rect2 = b.body()
		best = {"pos": Vector2(clampf(global_position.x, r.position.x, r.end.x), r.end.y), "node": b, "boss": true}
	return best


func _physics_process(dt: float) -> void:
	flash -= dt
	inv -= dt
	anim_t += dt
	if dead:
		dead_t += dt
		var n: int = frames.get("death", []).size()
		sprite.texture = _frame("death", int(dead_t * 14.0))
		var hold := maxf(0.4, n / 14.0 + 0.15)
		sprite.material = Fx.silhouette(Pal.L) if flash > 0.0 else null
		sprite.modulate = Color(SOUL, 1.0 - clampf((dead_t - hold) / 0.3, 0.0, 1.0))
		if dead_t > hold + 0.3:
			queue_free()
		return
	if rise > 0.0:  # sale de la tierra entre almas verdes
		rise -= dt
		var k := clampf(1.0 - rise / 0.55, 0.0, 1.0)
		sprite.modulate = Color(SOUL, k)
		sprite.position.y = roundf((1.0 - k) * 12.0)
		_look()
		if randf() < 0.5:
			Fx.part(get_parent(), global_position + Vector2(randf_range(-5, 5), 0), Vector2(randf_range(-10, 10), -randf_range(30, 70)), -20.0, 0.4, Pal.L if randf() < 0.6 else Pal.G)
		if randf() < 0.25:
			Fx.chunks(get_parent(), global_position + Vector2(randf_range(-4, 4), 0), 1, [Pal.SS, Color("c8b090")], 40.0, 30.0, global_position.y, 0.5, 0.4)
		velocity = Vector2(0, minf(velocity.y + GRAV * dt, 280.0))
		move_and_slide()
		return
	sprite.position.y = 0.0
	life -= dt
	if life <= 0.0 or owner_hero == null or not is_instance_valid(owner_hero) or owner_hero.dead:
		crumble()
		return
	# si su dueño se fue lejos (otra zona), aparece a su lado
	if absf(owner_hero.global_position.x - global_position.x) > 230.0 or global_position.y > 200.0:
		_puff()
		global_position = owner_hero.global_position + Vector2(-owner_hero.face * 14.0, -2.0)
		velocity = Vector2.ZERO
		_puff()

	var dir := _think(dt)
	if windup > 0.0 or shoot_t >= 0.0 or swing_t < 0.3:
		velocity.x *= maxf(0.0, 1.0 - 10.0 * dt)
	else:
		var want := dir * SPEED
		velocity.x += signf(want - velocity.x) * minf(absf(want - velocity.x), 500.0 * dt)
	velocity.y = minf(velocity.y + GRAV * dt, 280.0)
	if knock != 0.0:
		velocity.x += knock
		knock *= maxf(0.0, 1.0 - 6.0 * dt)
		if absf(knock) < 6.0:
			knock = 0.0
	move_and_slide()
	if knock != 0.0:
		velocity.x -= knock
	_attacks(dt)
	_touch()
	_animate(dt)


func _think(dt: float) -> float:
	cool -= dt
	if windup > 0.0 or shoot_t >= 0.0:
		return 0.0
	var tg := _target()
	if tg.is_empty():
		# sin nadie a quien pegarle: sigue a su dueño, un paso atrás
		var dx: float = owner_hero.global_position.x - owner_hero.face * 14.0 - global_position.x
		if absf(dx) > 10.0:
			face = signf(dx)
			return face
		face = float(owner_hero.face)
		return 0.0
	var d: Vector2 = tg.pos - global_position
	var dist := absf(d.x)
	if d.x != 0.0:
		face = signf(d.x)
	if kind == "skarch":
		if cool <= 0.0 and dist < 150.0 and absf(d.y) < 18.0 and is_on_floor():
			shoot_t = 0.0
			shot = false
			cool = 1.5 + randf() * 0.5
		return -face if dist < 44.0 else (face if dist > 110.0 else 0.0)
	var reach := 20.0 if tg.has("boss") else 16.0
	if dist < reach and absf(d.y) < 20.0 and cool <= 0.0 and is_on_floor():
		windup = 0.2
		cool = 1.1
		return 0.0
	return face if dist > reach - 4.0 else 0.0


func _attacks(dt: float) -> void:
	if windup > 0.0:
		windup -= dt
		if windup <= 0.0:
			swing_t = 0.0
			swing_hit = false
			Snd.play("tajo", {"rate": 0.9, "vol": 0.5})
			velocity.x += face * 40.0
			squash = Vector2(1.2, 0.86)
			Fx.slash(get_parent(), global_position + Vector2(face * 2.0, -12), 13.0, -110.0, 60.0, face, Pal.L, 4.0, 0.13)
	if swing_t < 0.3:
		swing_t += dt
		if swing_t >= 0.05 and swing_t < 0.16 and not swing_hit:
			var hb := Rect2(global_position.x + (1.0 if face > 0.0 else -19.0), global_position.y - 24, 18, 24)
			for e in get_tree().get_nodes_in_group("enemigos"):
				if e.dead or e.spawn > 0.0 or not e.has_method("hit_rect") or not e.hit_rect().intersects(hb):
					continue
				swing_hit = true
				e.take_hit(1, int(face), "sword")
			var b = game.boss if game != null else null
			if not swing_hit and b != null and is_instance_valid(b) and b.active() and b.body().intersects(hb):
				swing_hit = true
				b.damage(1, global_position.x + face * 10.0, global_position.y - 10.0, false, true)
			if swing_hit:
				Fx.burst(get_parent(), global_position + Vector2(face * 12.0, -8), 5, [Pal.L, Pal.W, Pal.G], 70.0, 30.0, 0.3, 200.0)
	if shoot_t >= 0.0:
		shoot_t += dt
		if shoot_t >= 0.26 and not shot:
			shot = true
			var a := EnemyArrow.new()
			a.face = face
			a.game = game
			a.hero = true
			a.hero_dmg = 1
			a.global_position = global_position + Vector2(face * 7.0, -11.0)
			get_parent().add_child(a)
			Snd.play("disparo", {"rate": 1.0, "vol": 0.45})
			Fx.twinkle(get_parent(), a.global_position + Vector2(face * 2.0, 0), Pal.L, 2.5, 0.12)
			velocity.x -= face * 25.0
			squash = Vector2(0.85, 1.1)
		if shoot_t >= 0.5:
			shoot_t = -1.0


## los enemigos que lo tocan lo lastiman (y el jefe, si no está aturdido)
func _touch() -> void:
	if inv > 0.0:
		return
	var me := hit_rect()
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.dead or e.spawn > 0.0 or not e.has_method("hit_rect") or not e.hit_rect().intersects(me):
			continue
		hurt(1, signf(global_position.x - e.global_position.x))
		return
	var b = game.boss if game != null else null
	if b != null and is_instance_valid(b) and b.active() and b.state != "stun" and b.body().intersects(me):
		hurt(1, signf(global_position.x - b.cx()))


func hurt(dmg: int, d: float) -> void:
	if dead or inv > 0.0 or rise > 0.0:
		return
	hp -= dmg
	inv = 0.7
	flash = 0.1
	knock = (d if d != 0.0 else -face) * 110.0
	velocity.y = -110.0
	windup = 0.0
	shoot_t = -1.0
	squash = Vector2(1.25, 0.8)
	Snd.play("huesos", {"rate": 1.5, "vol": 0.5})
	Fx.chunks(get_parent(), global_position + Vector2(0, -12), 2, BONE, 55.0, 40.0, global_position.y, 0.5, 0.5)
	if hp <= 0:
		crumble()


## se deshace: huesos que caen y el alma verde que se va
func crumble() -> void:
	if dead:
		return
	dead = true
	dead_t = 0.0
	flash = 0.1
	remove_from_group("aliados")
	Snd.play("huesos", {"rate": 1.1, "vol": 0.6})
	var at := global_position + Vector2(0, -10)
	Fx.chunks(get_parent(), at, 7, BONE, 70.0, 60.0, global_position.y, 1.0, 0.8)
	Fx.dust(get_parent(), global_position, 3, 20.0, 4.0, 1.8, Pal.SS)
	for i in 6:
		Fx.part(get_parent(), global_position + Vector2(randf_range(-4, 4), -randf_range(6, 18)), Vector2(randf_range(-8, 8), -randf_range(30, 60)), -25.0, 0.6, Pal.L if i % 2 == 0 else Pal.G)
	Fx.ring(get_parent(), at, Pal.L, 0.0, 10.0, 1.0, 0.25)


func _puff() -> void:
	Fx.ring(get_parent(), global_position + Vector2(0, -9), Pal.L, 0.0, 10.0, 1.0, 0.2)
	Fx.burst(get_parent(), global_position + Vector2(0, -9), 6, [Pal.L, Pal.G, Pal.W], 50.0, 20.0, 0.3, 0.0)


func _animate(dt: float) -> void:
	if inv > 0.45:
		var hn: int = frames.get("hurt", []).size()
		sprite.texture = _frame("hurt", int((1.0 - (inv - 0.45) / 0.25) * hn)) if hn > 0 else _frame("walk", 0)
	elif windup > 0.0:
		sprite.texture = _frame("atk", 1 if windup > 0.1 else 2)
	elif swing_t < 0.3:
		sprite.texture = _frame("atk", 3 + int(swing_t / 0.3 * 3.0))
	elif shoot_t >= 0.0:
		sprite.texture = _frame("atk", int(shoot_t / 0.5 * 6.0))
	elif absf(velocity.x) > 6.0:
		sprite.texture = _frame("walk", int(anim_t * 11.0) % maxi(1, frames.get("walk", []).size()))
	else:
		sprite.texture = _frame("idle", int(anim_t * 9.0) % maxi(1, frames.get("idle", []).size()))
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
	_look()
	sprite.material = Fx.silhouette(Pal.L) if flash > 0.0 else null
	# titila cuando le queda poco, y suelta almas verdes todo el tiempo
	var a := 1.0
	if life < 2.0 and int(life * 12.0) % 2 == 0:
		a = 0.45
	elif inv > 0.0 and int(inv * 20.0) % 2 == 0:
		a = 0.5
	sprite.modulate = Color.WHITE if flash > 0.0 else Color(SOUL, a)
	if randf() < 0.18:
		Fx.part(get_parent(), global_position + Vector2(randf_range(-4, 4), -randf_range(4, 20)), Vector2(0, -randf_range(14, 26)), -10.0, 0.45, Pal.L if randf() < 0.6 else Pal.G)


func _look() -> void:
	sprite.scale = Vector2(0.5 * squash.x * (1.0 if face >= 0.0 else -1.0), 0.5 * squash.y)
