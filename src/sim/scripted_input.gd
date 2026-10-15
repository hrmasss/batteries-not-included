class_name ScriptedInput
extends RefCounted
## A timeline of intents in seconds: the input source for tests, screenshot runs, drills and,
## later, recorded inputs replayed on another ruleset (US-37.4).
##
## Each step holds from its time until the next step. Fields not given carry over from the
## step before. Step shape (JSON or Dictionary):
##   {"t": 1.5, "move": [x, y], "held": true, "aim": [x, y], "fire": false, "buttons": 0}
## `held` defaults to true when `move` is not zero.

var _times: PackedFloat64Array = []
var _intents: Array[InputIntent] = []


static func from_steps(steps: Array) -> ScriptedInput:
	var s := ScriptedInput.new()
	var sorted := steps.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	var last := InputIntent.idle()
	for step: Dictionary in sorted:
		var i := last.copy()
		if step.has("move"):
			i.move = Vector2(float(step.move[0]), float(step.move[1]))
			i.move_held = i.move != Vector2.ZERO
		if step.has("held"):
			i.move_held = bool(step.held)
		if step.has("aim"):
			i.aim = Vector2(float(step.aim[0]), float(step.aim[1]))
		if step.has("fire"):
			i.fire = bool(step.fire)
		if step.has("buttons"):
			i.buttons = int(step.buttons)
		s._times.append(float(step.t))
		s._intents.append(i)
		last = i
	return s


static func from_json_file(path: String) -> ScriptedInput:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		data = data.get("steps", [])
	if typeof(data) != TYPE_ARRAY:
		push_error("ScriptedInput: %s holds no steps" % path)
		return ScriptedInput.new()
	return from_steps(data)


## The intent in force at `seconds`.
func intent_at(seconds: float) -> InputIntent:
	var found := InputIntent.idle()
	for k in _times.size():
		if _times[k] <= seconds + 1e-6:
			found = _intents[k]
		else:
			break
	return found


func end_time() -> float:
	return _times[-1] if not _times.is_empty() else 0.0
