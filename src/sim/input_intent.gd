class_name InputIntent
extends RefCounted
## What one player wants for one tick. The only thing an app, a bot or the network hands the
## match server (rule A1). Touch sticks, keyboard, gamepad, bots and replays all produce this.
##
## Stick space: x right, y up, each axis -1 to 1, length at most 1. `move_held` says the thumb
## is on the move stick even when the stick sits at its centre; the classic treats a touched
## stick and a released one differently.

enum Act {
	GRENADE = 1,
	MELEE = 2,
	RELOAD = 4,
	SWITCH = 8,
	PICK_UP = 16,
	ZOOM = 32,
	GRENADE_SWITCH = 64,
}

## Move stick, y up.
var move: Vector2 = Vector2.ZERO
## The thumb is on the move stick.
var move_held: bool = false
## Aim stick direction, y up. Zero when not aiming.
var aim: Vector2 = Vector2.ZERO
## Fire held.
var fire: bool = false
## Held buttons, a mask of `Act`.
var buttons: int = 0


static func idle() -> InputIntent:
	return InputIntent.new()


static func make(move_stick: Vector2, held: bool = true, aim_stick: Vector2 = Vector2.ZERO) -> InputIntent:
	var i := InputIntent.new()
	i.move = move_stick
	i.move_held = held
	i.aim = aim_stick
	return i


func is_down(button: Act) -> bool:
	return buttons & int(button) != 0


func set_button(button: Act, down: bool) -> void:
	if down:
		buttons |= int(button)
	else:
		buttons &= ~int(button)


## A copy the match server can trust the shape of: finite, sticks no longer than 1, known
## buttons only. The server never trusts the numbers a client sends (01_world, "The host decides").
func sanitized() -> InputIntent:
	var i := InputIntent.new()
	i.move = _clamp_stick(move)
	i.move_held = move_held
	i.aim = _clamp_stick(aim)
	i.fire = fire
	i.buttons = buttons & 127
	return i


func copy() -> InputIntent:
	var i := InputIntent.new()
	i.move = move
	i.move_held = move_held
	i.aim = aim
	i.fire = fire
	i.buttons = buttons
	return i


func equals(other: InputIntent) -> bool:
	return move == other.move and move_held == other.move_held and aim == other.aim \
		and fire == other.fire and buttons == other.buttons


func to_dict() -> Dictionary:
	return {"move": [move.x, move.y], "held": move_held, "aim": [aim.x, aim.y], "fire": fire, "buttons": buttons}


static func from_dict(d: Dictionary) -> InputIntent:
	var i := InputIntent.new()
	var m: Array = d.get("move", [0, 0])
	var a: Array = d.get("aim", [0, 0])
	i.move = Vector2(float(m[0]), float(m[1]))
	i.move_held = bool(d.get("held", i.move != Vector2.ZERO))
	i.aim = Vector2(float(a[0]), float(a[1]))
	i.fire = bool(d.get("fire", false))
	i.buttons = int(d.get("buttons", 0))
	return i


static func _clamp_stick(v: Vector2) -> Vector2:
	if not v.is_finite():
		return Vector2.ZERO
	return v.limit_length(1.0)
