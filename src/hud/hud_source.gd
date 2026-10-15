class_name HudSource
extends RefCounted
## Where the HUD's numbers come from. The HUD calls `read` each frame and draws what it gets.
##
## `SimHudSource` reads the match. Until the combat task lands, `CombatStub` stands in for the
## numbers the sim does not have yet (ammo, grenades, scores, clock, kill feed, pops); swap it
## for the real thing and the HUD does not change.

func read(_into: HudState, _dt: float) -> void:
	pass
