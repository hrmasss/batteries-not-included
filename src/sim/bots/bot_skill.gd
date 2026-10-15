class_name BotSkill
extends RefCounted
## One bot skill level (T-95 to T-97) with the shared brain values filled in, read from a
## ruleset's `bots.cfg` by `BotSkills`. What a bot decides, never what its toy can do (T-98).
## Meanings and units: the comments in `data/rulesets/standard/bots.cfg`.

var id: StringName = &""

# shared
var look_interval: float
var think_interval: float
var memory: float
var wander_min: float
var wander_max: float
var stuck_time: float
var stuck_distance: float
var battery_low: float
var battery_resume: float
var cruise_share: float
var arrive: float
var steer_gain: float
var reach: float
var fight_share: float
var fight_min: float
var fight_max: float
var strafe: float
var strafe_min: float
var strafe_max: float
var melee_range: float
var grenade_min: float
var grenade_max: float
var grenade_mate_gap: float
var throw_aim_time: float
var frag_value: float
var cover_tries: float
var want_health: float
var retreat_health: float
var reload_share: float
var eye_height: float
var nav_cell: float
var air_cost: float

# per level
var sight: float
var reaction: float
var turn_rate: float
var turn_gain: float
var aim_dead_zone: float
var aim_error: float
var aim_wobble: float
var lead: float
var fire_cone: float
var first_wait: float
var first_burst: float
var wait_min: float
var wait_max: float
var burst_min: float
var burst_max: float
var grenade_cooldown: float


func to_dict() -> Dictionary:
	var out := {}
	for f: Dictionary in BotSkills.FIELDS:
		out[f.key] = get(f.key)
	return out
