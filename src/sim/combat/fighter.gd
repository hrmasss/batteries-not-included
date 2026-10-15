class_name Fighter
extends RefCounted
## A toy's fighting state on the match server: team, weapons, grenades, health timers,
## protection, respawn and score (01_world "Weapons and damage" to "Spawning").
## Only `CombatSim` writes it (rule A1); the view and the HUD read it.

## A toy carries this many weapons (US-07.1): a rule of the game, not a tuning value.
const SLOTS := 2
## No team: free-for-all. Toys with the same team above this are teammates.
const NO_TEAM := 0

var toy: SimToy
var team: int = NO_TEAM
var alive: bool = true

## Up to two carried weapons (US-07.1); `held` is the one in the main hand.
var weapons: Array[WeaponItem] = []
var held: int = 0
## Grenades carried, by type (T-60 caps the total). `grenade_type` is the one thrown next.
var grenades: Dictionary = {}
var grenade_type: StringName = &""

## Aim in world space (y down), unit length.
var aim: Vector2 = Vector2.RIGHT
var zoom_level: int = 1
## Last zoom level used with each weapon id (US-10.3).
var zoom_memory: Dictionary = {}

var protect_left: float = 0.0
var respawn_left: float = 0.0
var lunge_meter: float = 0.0
var swing_left: float = 0.0
var swing_dir: Vector2 = Vector2.RIGHT
## The swing under way has hit someone.
var swing_landed: bool = true
var pack_pending: float = 0.0
var battery_pack_left: float = 0.0
var out_of_bounds_time: float = 0.0
## The last toy that hurt this one, for kill credit with no attacker (US-15.2).
var last_damager: int = 0
## Who popped this toy and with what, for the respawn screen (US-15.5).
var popped_by: int = 0
var popped_with: StringName = &""
## The weapon on the floor within reach, offered for the pick-up button (US-07.3); -1 none.
var offer: int = -1

var kills: int = 0
var deaths: int = 0
var suicides: int = 0
var team_kills: int = 0

var prev_buttons: int = 0


func id() -> int:
	return toy.toy_id


func main_weapon() -> WeaponItem:
	return weapons[held] if held < weapons.size() else null


## US-08.1: both carried weapons are dual-capable, so the other one sits in the off hand.
func is_dual() -> bool:
	return weapons.size() == SLOTS and weapons[0].def.dual and weapons[1].def.dual


func off_weapon() -> WeaponItem:
	return weapons[1 - held] if is_dual() else null


func grenade_count() -> int:
	var n := 0
	for k: StringName in grenades:
		n += int(grenades[k])
	return n


func is_protected() -> bool:
	return protect_left > 0.0


func is_teammate(other: Fighter) -> bool:
	return other != self and team != NO_TEAM and team == other.team
