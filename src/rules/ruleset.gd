class_name Ruleset
extends RefCounted
## The full set of tuning values a match runs on (01_world "Rulesets").
##
## Built only by `RulesetLoader`, which fills every field from data and refuses a ruleset with
## a missing or out-of-range value. The fields carry no start values on purpose: a number that
## lived here would be a number in code (US-43.1). The meaning, tuning name and range of each
## field is in `RulesetSchema`.

var id: String = ""
var name: String = ""
var version: int = 0

# movement
var walk_gravity: float
var fly_gravity: float
var walk_speed: float
var walk_catch_up: float
var fly_speed: float
var fly_catch_up: float
var speed_kept_per_second: float
var top_speed: float
var brake_full_below: float
var brake_none_above: float
var brake_rate: float
var jump_speed: float
var jump_stick_up: float
var jump_cooldown: float
var jump_ground_grace: float
var engage_airtime: float
var engage_deflection: float
var engage_up: float
var landing_cutoff_speed: float
var crouch_start_down: float
var crouch_hold_down: float
var stand_up_delay: float
var lean_facing_flying: float
var lean_facing_ground: float
var offhand_weight_share: float

# hitbox
var body_width: float
var body_bottom: float
var body_top: float
var head_radius: float
var head_height: float
var crouch_width: float
var crouch_bottom: float
var crouch_top: float

# surfaces
var toy_bounce_idle: float
var toy_friction_idle: float
var toy_bounce_walking: float
var toy_friction_walking: float
var toy_bounce_flying: float
var toy_friction_flying: float
var terrain_bounce: float
var terrain_friction: float
var bounce_min_speed: float

# battery
var battery_full: float
var drain_rate: float
var drain_floor_share: float
var refill_pause: float
var refill_rate: float

# health
var max_health: float

# camera
var anchor_below_middle: float
var view_height: float

# modifiers
var batteries_included: bool
var battery_size: float


func copy() -> Ruleset:
	var r := Ruleset.new()
	r.id = id
	r.name = name
	r.version = version
	for f: Dictionary in RulesetSchema.FIELDS:
		r.set(f.key, get(f.key))
	return r


## Plain values by key, for sending to joiners and for comparing two rulesets.
func to_dict() -> Dictionary:
	var out := {"id": id, "name": name, "version": version}
	for f: Dictionary in RulesetSchema.FIELDS:
		out[f.key] = get(f.key)
	return out
