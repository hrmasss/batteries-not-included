class_name InputSource
extends Node
## Where the local player's intent comes from: desktop devices, a script, later touch sticks.
## The view asks once per tick.


func intent_for(_view: GameView, _tick: int) -> InputIntent:
	return InputIntent.idle()
