class_name Ctl
## Los controles de cada jugador. Un "dispositivo" es null (cualquiera: un solo jugador, como siempre),
## KB (solo el teclado) o el número de un joystick. Cada dispositivo tiene sus propias acciones en el
## InputMap ("kb_saltar", "j0_saltar"...), así "recién apretado" anda igual que con las acciones comunes.
## Joystick: cruz o palanca mover · A saltar · X o RB atacar · B o LB especial · Y poder · START empezar.

const KB := -1
const MAX_PADS := 8
const KEYS := {
	"izquierda": [KEY_LEFT, KEY_A], "derecha": [KEY_RIGHT, KEY_D], "abajo": [KEY_DOWN, KEY_S], "arriba": [KEY_UP, KEY_W],
	"saltar": [KEY_SPACE, KEY_Z, KEY_K], "atacar": [KEY_X, KEY_J], "especial": [KEY_SHIFT, KEY_V, KEY_L],
	"poder": [KEY_C, KEY_E, KEY_I], "start": [KEY_ENTER, KEY_KP_ENTER], "back": [KEY_ESCAPE, KEY_BACKSPACE],
}
const BTNS := {
	"izquierda": [JOY_BUTTON_DPAD_LEFT], "derecha": [JOY_BUTTON_DPAD_RIGHT], "abajo": [JOY_BUTTON_DPAD_DOWN],
	"arriba": [JOY_BUTTON_DPAD_UP], "saltar": [JOY_BUTTON_A], "atacar": [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER],
	"especial": [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER], "poder": [JOY_BUTTON_Y], "start": [JOY_BUTTON_START],
	"back": [JOY_BUTTON_BACK],
}
const AXES := {"izquierda": [JOY_AXIS_LEFT_X, -1.0], "derecha": [JOY_AXIS_LEFT_X, 1.0], "abajo": [JOY_AXIS_LEFT_Y, 1.0], "arriba": [JOY_AXIS_LEFT_Y, -1.0]}

static var virt: Array = []   # joysticks de mentira (solo para las pruebas automáticas)


static func setup() -> void:
	if InputMap.has_action("kb_saltar"):
		return
	for a in KEYS:
		InputMap.add_action("kb_" + a, 0.5)
		for k in KEYS[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event("kb_" + a, e)
		for d in MAX_PADS:
			var n := "j%d_%s" % [d, a]
			InputMap.add_action(n, 0.5)
			for b in BTNS[a]:
				var j := InputEventJoypadButton.new()
				j.device = d
				j.button_index = b
				InputMap.action_add_event(n, j)
			if AXES.has(a):
				var m := InputEventJoypadMotion.new()
				m.device = d
				m.axis = AXES[a][0]
				m.axis_value = AXES[a][1]
				InputMap.action_add_event(n, m)


static func act(dev, a: String) -> String:
	if dev == null:
		return a
	return "kb_" + a if dev == KB else "j%d_%s" % [dev, a]


static func down(dev, a: String) -> bool:
	return Input.is_action_pressed(act(dev, a))


static func tap(dev, a: String) -> bool:
	return Input.is_action_just_pressed(act(dev, a))


## el teclado y los joysticks conectados
static func devices() -> Array:
	var out: Array = [KB]
	for d in Input.get_connected_joypads():
		if d < MAX_PADS and not out.has(d):
			out.append(d)
	for d in virt:
		if not out.has(d):
			out.append(d)
	return out


static func label(dev) -> String:
	return "TECLADO" if dev == KB else "JOYSTICK %d" % (dev + 1)


static func tag(dev) -> String:
	return "TEC" if dev == KB else "J%d" % (dev + 1)


static func color(dev) -> Color:
	if dev == KB:
		return Pal.W
	return [Pal.Y, Pal.C, Pal.L, Pal.O][dev % 4]
