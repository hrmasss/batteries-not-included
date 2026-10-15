class_name HudSource
extends RefCounted
## Where the HUD's numbers come from. The HUD calls `read` each frame and draws what it gets.
##
## `SimHudSource` reads the match. A test or a tool can hand the HUD any other source; the HUD
## does not change.

func read(_into: HudState, _dt: float) -> void:
	pass
