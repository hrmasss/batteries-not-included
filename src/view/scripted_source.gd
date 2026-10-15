class_name ScriptedSource
extends InputSource
## Plays a `ScriptedInput` timeline by tick time, for screenshots and recordings.

var script_input: ScriptedInput


func _init(timeline: ScriptedInput = null) -> void:
	script_input = timeline


func intent_for(_view: GameView, tick: int) -> InputIntent:
	return script_input.intent_at(tick * SimClock.TICK) if script_input != null else InputIntent.idle()
