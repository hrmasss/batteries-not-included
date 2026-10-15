class_name HudState
extends RefCounted
## Everything the HUD shows for one player, as plain values (US-25). Filled each frame by a
## `HudSource`; the HUD only reads it. Nothing here is a rule: the match decides every number.

class Grenade:
	extends RefCounted
	var kind: StringName = &"frag"
	var count: int = 0


class FeedLine:
	extends RefCounted
	var killer: String = ""
	var killer_team: int = -1
	var victim: String = ""
	var victim_team: int = -1
	var weapon: String = ""
	## Seconds since it happened.
	var age: float = 0.0
	var suicide: bool = false


class Score:
	extends RefCounted
	## Team index, or -1 for one player in free-for-all.
	var team: int = -1
	var name: String = ""
	var kills: int = 0
	var mine: bool = false


class Contact:
	extends RefCounted
	## Another toy as the radar sees it.
	var toy_id: int = 0
	var team: int = -1
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var alive: bool = true
	## Fired since the last frame (a radar alert).
	var fired: bool = false
	var name: String = ""


var health: float = 0.0
var health_max: float = 100.0
var battery: float = 0.0
var battery_max: float = 100.0
## Batteries Included: draw the battery as infinite (US-25.2).
var batteries_included: bool = false
var weapon_name: String = ""
var magazine: int = 0
var reserve: int = 0
## Infinite ammo under Batteries Included.
var ammo_infinite: bool = false
var reloading: bool = false
## Grenades by kind, the selected one first.
var grenades: Array[Grenade] = []
## Seconds left in the match; negative hides the clock.
var clock: float = -1.0
var scores: Array[Score] = []
var feed: Array[FeedLine] = []
## Popped and waiting: seconds to respawn, who popped me and with what.
var popped: bool = false
var respawn_in: float = 0.0
var popped_by: String = ""
var popped_by_team: int = -1
var popped_with: String = ""
## Spawn protection left, seconds.
var protected_for: float = 0.0
## Hits this frame: world positions the damage came from.
var hits_from: Array[Vector2] = []
var my_team: int = -1
var my_position: Vector2 = Vector2.ZERO
var contacts: Array[Contact] = []
## Something in pick-up reach.
var can_pick_up: bool = false
## Team mode: teams score; else every player for themselves.
var team_mode: bool = false
