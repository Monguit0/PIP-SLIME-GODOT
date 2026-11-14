extends RefCounted
## El turbo del bicho que manejás en el modo Villano (slimes y esqueletos): mientras mantenés el especial va
## mucho más rápido y la barra se gasta; al soltarlo se recarga sola. Si la vaciás del todo queda bloqueada
## hasta juntar un cuarto. También dibuja las marcas del que manejás: la flecha amarilla y las barritas.

const MUL := 2.6        # cuánto más rápido va
const TIME := 1.8       # segundos que dura la barra llena
const FILL := 2.6       # segundos que tarda en llenarse de cero
const WAIT := 0.45      # espera antes de empezar a recargar
const MIN := 0.25       # si la vaciaste, hay que esperar a que junte esto para volver a usarla

var level := 1.0
var on := false
var wait := 0.0
var empty := false


func reset() -> void:
	level = 1.0
	on = false
	wait = 0.0
	empty = false


## Un paso. want: tiene el especial apretado y puede moverse. m: el bicho (para los efectos); col: su color.
## top: cuánto más arriba de los pies está el medio del cuerpo. Devuelve true mientras el turbo está andando.
func step(m: CharacterBody2D, dt: float, want: bool, face: float, col: Color, top: float) -> bool:
	var par := m.get_parent()
	var at := m.global_position
	want = want and not empty and level > 0.0
	if want and not on:  # arranca: un empujón, aro y salpicón
		Snd.play("dash", {"rate": 1.3, "vol": 0.55})
		Snd.play("baba", {"rate": 0.9, "vol": 0.6})
		Fx.kick(Vector2(face, 0), 0.7)
		Fx.ring(par, at + Vector2(-face * 3.0, -top), col, 0.0, 9.0, 0.6, 0.2)
		Fx.goo(par, at + Vector2(0, -3), 6, col, 70.0, at.y)
		m.velocity.x += face * 60.0
		m.set("squash", Vector2(1.5, 0.6))
	on = want
	if on:
		level = maxf(0.0, level - dt / TIME)
		wait = WAIT
		# resbala: gotas que quedan atrás, manchitas en el piso y líneas de velocidad
		if absf(m.velocity.x) > 40.0:
			var bd := signf(m.velocity.x)
			Fx.part(par, at + Vector2(-bd * 5.0, -randf_range(1, top + 2.0)), Vector2(-bd * randf_range(20, 60), -randf_range(0, 30)), 200.0, 0.3, col if randf() < 0.7 else Pal.W, 2 if randf() < 0.4 else 1)
			if m.is_on_floor() and Engine.get_physics_frames() % 4 == 0:
				Fx.splat(par, at + Vector2(-bd * 4.0, 0), col, 5.0)
			if Engine.get_physics_frames() % 5 == 0:
				Fx.streak(par, at + Vector2(-bd * 3.0, -randf_range(1, top * 2.0)), Vector2(-bd * 120.0, 0), 0.1, Pal.W, 6.0)
			if Engine.get_physics_frames() % 9 == 0:
				Snd.play("baba", {"rate": 1.8, "vol": 0.18})
		if level <= 0.0:  # se quedó sin turbo: frena y queda bloqueado un rato
			empty = true
			on = false
			m.set("squash", Vector2(0.8, 1.25))
			Snd.play("dano", {"rate": 1.8, "vol": 0.3})
			Fx.popup(par, at + Vector2(0, -top * 2.0 - 10.0), "¡SIN TURBO!", Pal.O)
	else:
		wait -= dt
		if wait <= 0.0 and level < 1.0:
			var was := level
			level = minf(1.0, level + dt / FILL)
			if empty and level >= MIN:
				empty = false
			if was < 1.0 and level >= 1.0:  # llena de nuevo
				Fx.twinkle(par, at + Vector2(0, -top), Pal.C, 2.5, 0.16)
				Snd.play("menu", {"rate": 1.8, "vol": 0.25, "vary": false})
	return on


## la barra, debajo del bicho: celeste; blanca titilando mientras se usa; naranja si se vació
func draw_bar(ci: CanvasItem) -> void:
	if level >= 1.0 and not on:
		return
	ci.draw_rect(Rect2(-7.5, 1.5, 15.0, 3.0), Pal.K)
	var tc: Color = Pal.C
	if empty:
		tc = Pal.O if Engine.get_physics_frames() % 10 < 5 else Pal.R
	elif on and Engine.get_physics_frames() % 6 < 3:
		tc = Pal.W
	ci.draw_rect(Rect2(-7.0, 2.0, 14.0 * level, 2.0), tc)
	ci.draw_rect(Rect2(-7.0 + 14.0 * MIN, 2.0, 0.5, 2.0), Pal.K)  # lo mínimo para volver a usarlo


## la flechita amarilla sobre el que manejás (y: la punta, sobre la cabeza)
static func draw_marker(ci: CanvasItem, y: float) -> void:
	var by := y + roundf(sin(Time.get_ticks_msec() / 1000.0 * 6.0) * 1.0)
	for i in 3:
		ci.draw_rect(Rect2(-2.5 + i, by + i - 0.5, 5.0 - 2.0 * i, 1.0), Pal.K)
	for i in 2:
		ci.draw_rect(Rect2(-1.5 + i, by + i - 0.5, 3.0 - 2.0 * i, 1.0), Pal.Y)


static func draw_hp(ci: CanvasItem, y: float, hp: int, max_hp: int) -> void:
	ci.draw_rect(Rect2(-5.5, y - 0.5, 11.0, 3.0), Pal.K)
	ci.draw_rect(Rect2(-5.0, y, 10.0 * hp / max_hp, 2.0), Pal.R)
