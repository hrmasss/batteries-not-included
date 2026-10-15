class_name DesktopInput
extends RefCounted
## Keyboard and mouse into an `InputIntent`, for desktop play and testing: WASD or arrows move,
## the mouse aims from the toy, the left button fires. Buttons: G grenade, V melee, R reload,
## Q switch, E pick up, Z zoom (or the right mouse button), X grenade switch.
##
## Reads device state only; the view hands it the toy's screen position for aiming.

const KEYS := {
	KEY_G: InputIntent.Act.GRENADE,
	KEY_V: InputIntent.Act.MELEE,
	KEY_R: InputIntent.Act.RELOAD,
	KEY_Q: InputIntent.Act.SWITCH,
	KEY_E: InputIntent.Act.PICK_UP,
	KEY_Z: InputIntent.Act.ZOOM,
	KEY_X: InputIntent.Act.GRENADE_SWITCH,
}


## Fills `intent` from the keyboard and mouse. `toy_screen` and `mouse` are in the same screen
## space (viewport pixels).
static func fill(intent: InputIntent, toy_screen: Vector2, mouse: Vector2) -> void:
	var m := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		m.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		m.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_SPACE):
		m.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		m.y -= 1.0
	intent.move = m.limit_length(1.0)
	intent.move_held = m != Vector2.ZERO
	var d := mouse - toy_screen
	intent.aim = Vector2(d.x, -d.y).normalized() if d.length() > 4.0 else Vector2.ZERO
	intent.fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var b := 0
	for key: Key in KEYS:
		if Input.is_physical_key_pressed(key):
			b |= int(KEYS[key])
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		b |= InputIntent.Act.ZOOM
	intent.buttons = b
