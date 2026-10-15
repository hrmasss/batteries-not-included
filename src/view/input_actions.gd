class_name InputActions
extends RefCounted
## Desktop bindings for testing: WASD and a gamepad's left stick move, the mouse or the right
## stick aims. Touch sticks come later and feed the same `InputIntent`.

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const MOVE_UP := &"move_up"
const MOVE_DOWN := &"move_down"
const AIM_LEFT := &"aim_left"
const AIM_RIGHT := &"aim_right"
const AIM_UP := &"aim_up"
const AIM_DOWN := &"aim_down"
const FIRE := &"fire"
const DEBUG_OVERLAY := &"debug_overlay"
const DEBUG_HITBOXES := &"debug_hitboxes"
const DEBUG_RESPAWN := &"debug_respawn"

## Action, the intent button it sets, keys, gamepad buttons.
const BUTTONS := [
	[&"grenade", InputIntent.Act.GRENADE, [KEY_G], [JOY_BUTTON_LEFT_SHOULDER]],
	[&"melee", InputIntent.Act.MELEE, [KEY_F], [JOY_BUTTON_B]],
	[&"reload", InputIntent.Act.RELOAD, [KEY_R], [JOY_BUTTON_X]],
	[&"switch_weapon", InputIntent.Act.SWITCH, [KEY_Q], [JOY_BUTTON_Y]],
	[&"pick_up", InputIntent.Act.PICK_UP, [KEY_E], [JOY_BUTTON_A]],
	[&"zoom", InputIntent.Act.ZOOM, [KEY_Z], [JOY_BUTTON_RIGHT_STICK]],
	[&"grenade_switch", InputIntent.Act.GRENADE_SWITCH, [KEY_X], [JOY_BUTTON_DPAD_DOWN]],
]

const STICK_DEADZONE := 0.2


## Adds the actions once, unless the project already defines them.
static func ensure() -> void:
	_axis(MOVE_LEFT, [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_axis(MOVE_RIGHT, [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_axis(MOVE_UP, [KEY_W, KEY_UP, KEY_SPACE], JOY_AXIS_LEFT_Y, -1.0)
	_axis(MOVE_DOWN, [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_axis(AIM_LEFT, [], JOY_AXIS_RIGHT_X, -1.0)
	_axis(AIM_RIGHT, [], JOY_AXIS_RIGHT_X, 1.0)
	_axis(AIM_UP, [], JOY_AXIS_RIGHT_Y, -1.0)
	_axis(AIM_DOWN, [], JOY_AXIS_RIGHT_Y, 1.0)
	if not InputMap.has_action(FIRE):
		InputMap.add_action(FIRE)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(FIRE, mouse)
		var trigger := InputEventJoypadMotion.new()
		trigger.axis = JOY_AXIS_TRIGGER_RIGHT
		trigger.axis_value = 1.0
		InputMap.action_add_event(FIRE, trigger)
	for b: Array in BUTTONS:
		_buttons(b[0], b[2], b[3])
	_buttons(DEBUG_OVERLAY, [KEY_F1], [])
	_buttons(DEBUG_HITBOXES, [KEY_F2], [])
	_buttons(DEBUG_RESPAWN, [KEY_F5], [JOY_BUTTON_BACK])


static func _axis(action: StringName, keys: Array, axis: JoyAxis, dir: float) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, STICK_DEADZONE)
	for k: Key in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = dir
	InputMap.action_add_event(action, m)


static func _buttons(action: StringName, keys: Array, pads: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k: Key in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for p: JoyButton in pads:
		var j := InputEventJoypadButton.new()
		j.button_index = p
		InputMap.action_add_event(action, j)
