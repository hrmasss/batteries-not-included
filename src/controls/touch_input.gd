class_name TouchInput
extends InputSource
## The local player's input on a phone: the touch sticks and buttons while a thumb is on the
## screen and for a moment after, keyboard, mouse and gamepad otherwise (desktop keeps working).

## Seconds after the last touch before the desktop devices take over again.
const TOUCH_GRACE := 2.0

var controls: TouchControls
var desktop := DesktopInput.new()


func _ready() -> void:
	if desktop.get_parent() == null:
		add_child(desktop)


func intent_for(view: GameView, tick: int) -> InputIntent:
	if controls != null and controls.is_active() and controls.since_touch < TOUCH_GRACE:
		var i := InputIntent.new()
		controls.fill(i)
		return i
	return desktop.intent_for(view, tick)
