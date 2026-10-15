class_name RulesetSchema
extends RefCounted
## Every value a ruleset must hold: where it lives, which tuning name it carries, its range.
##
## This file holds names and allowed ranges, never values. The values live in the data files
## under `data/rulesets/<name>/`, one file per group, grouped as `docs/specs/04_tuning.md`
## groups them in the workspace. A key is unique across groups and is also the property name
## on `Ruleset`.
##
## `tid` is the tuning name (T-N). An empty `tid` marks a value the classic has but 04_tuning
## does not name yet; each one has a row in the workspace's `recon/questions.md`.

const GROUPS: PackedStringArray = ["movement", "hitbox", "surfaces", "battery", "health", "camera", "modifiers"]

const FLOAT := TYPE_FLOAT
const BOOL := TYPE_BOOL

## group, key, tid, type, min, max, unit, what
const FIELDS: Array[Dictionary] = [
	# Movement (T-1 to T-19)
	{"group": "movement", "key": "walk_gravity", "tid": "T-1", "type": FLOAT, "min": 0.0, "max": 5000.0, "unit": "u/s²", "what": "Gravity on foot or falling"},
	{"group": "movement", "key": "fly_gravity", "tid": "T-2", "type": FLOAT, "min": 0.0, "max": 5000.0, "unit": "u/s²", "what": "Gravity while the jetpack is engaged"},
	{"group": "movement", "key": "walk_speed", "tid": "T-3", "type": FLOAT, "min": 0.0, "max": 2000.0, "unit": "u/s", "what": "Walk target speed at full sideways stick, before weight"},
	{"group": "movement", "key": "walk_catch_up", "tid": "T-4", "type": FLOAT, "min": 0.0, "max": 100.0, "unit": "/s", "what": "Share of missing walk speed closed per second, before weight"},
	{"group": "movement", "key": "fly_speed", "tid": "T-5", "type": FLOAT, "min": 0.0, "max": 2000.0, "unit": "u/s", "what": "Fly target speed along the stick, before weight"},
	{"group": "movement", "key": "fly_catch_up", "tid": "T-6", "type": FLOAT, "min": 0.0, "max": 100.0, "unit": "/s", "what": "Share of missing fly speed closed per second, before weight and deflection"},
	{"group": "movement", "key": "speed_kept_per_second", "tid": "T-7", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "share", "what": "Air drag: share of speed kept after one second"},
	{"group": "movement", "key": "top_speed", "tid": "T-8", "type": FLOAT, "min": 1.0, "max": 10000.0, "unit": "u/s", "what": "Hard speed cap"},
	{"group": "movement", "key": "brake_full_below", "tid": "T-9", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "u/s", "what": "Ground brake works fully below this speed"},
	{"group": "movement", "key": "brake_none_above", "tid": "T-9", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "u/s", "what": "Ground brake stops working above this speed"},
	{"group": "movement", "key": "brake_rate", "tid": "T-9", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "/s", "what": "Share of speed the full brake removes per second (at most all of it per step)"},
	{"group": "movement", "key": "jump_speed", "tid": "T-10", "type": FLOAT, "min": 0.0, "max": 2000.0, "unit": "u/s", "what": "Upward speed a jump adds"},
	{"group": "movement", "key": "jump_stick_up", "tid": "T-11", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "stick", "what": "Stick up past this jumps"},
	{"group": "movement", "key": "jump_cooldown", "tid": "T-12", "type": FLOAT, "min": 0.0, "max": 10.0, "unit": "s", "what": "Least time between jumps"},
	{"group": "movement", "key": "jump_ground_grace", "tid": "T-12", "type": FLOAT, "min": 0.0, "max": 10.0, "unit": "s", "what": "A jump still works this long after leaving the ground"},
	{"group": "movement", "key": "engage_airtime", "tid": "T-13", "type": FLOAT, "min": 0.0, "max": 10.0, "unit": "s", "what": "Airtime before the jetpack can engage"},
	{"group": "movement", "key": "engage_deflection", "tid": "T-14", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "stick", "what": "Stick deflection past this can engage the jetpack"},
	{"group": "movement", "key": "engage_up", "tid": "T-14", "type": FLOAT, "min": -1.0, "max": 1.0, "unit": "stick", "what": "Stick up past this can engage the jetpack"},
	{"group": "movement", "key": "landing_cutoff_speed", "tid": "T-15", "type": FLOAT, "min": 0.0, "max": 2000.0, "unit": "u/s", "what": "Touching down with the stick pulled down below this speed ends flight"},
	{"group": "movement", "key": "crouch_start_down", "tid": "T-16", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "stick", "what": "Stick down past this crouches"},
	{"group": "movement", "key": "crouch_hold_down", "tid": "T-16", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "stick", "what": "Stick down past this keeps the crouch"},
	{"group": "movement", "key": "stand_up_delay", "tid": "T-16", "type": FLOAT, "min": 0.0, "max": 10.0, "unit": "s", "what": "Stand up this long after the crouch is let go"},
	{"group": "movement", "key": "lean_facing_flying", "tid": "T-17", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "weight", "what": "Body lean weight on facing while flying; the stick gets the rest"},
	{"group": "movement", "key": "lean_facing_ground", "tid": "T-17", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "weight", "what": "Body lean weight on facing otherwise; the stick gets the rest"},
	{"group": "movement", "key": "offhand_weight_share", "tid": "T-19", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "share", "what": "The off-hand weight counts as off-hand × (1 − share) + share; 0.5 gives (off-hand + 1) / 2"},
	# Hitbox (T-18), in u, y up, from the body origin
	{"group": "hitbox", "key": "body_width", "tid": "T-18", "type": FLOAT, "min": 1.0, "max": 500.0, "unit": "u", "what": "Body box width"},
	{"group": "hitbox", "key": "body_bottom", "tid": "T-18", "type": FLOAT, "min": -500.0, "max": 0.0, "unit": "u", "what": "Body box bottom (the feet), below the body origin"},
	{"group": "hitbox", "key": "body_top", "tid": "T-18", "type": FLOAT, "min": -500.0, "max": 500.0, "unit": "u", "what": "Body box top, from the body origin"},
	{"group": "hitbox", "key": "head_radius", "tid": "T-18", "type": FLOAT, "min": 0.0, "max": 500.0, "unit": "u", "what": "Head circle radius"},
	{"group": "hitbox", "key": "head_height", "tid": "T-18", "type": FLOAT, "min": -500.0, "max": 500.0, "unit": "u", "what": "Head circle centre above the body origin"},
	{"group": "hitbox", "key": "crouch_width", "tid": "T-18", "type": FLOAT, "min": 0.0, "max": 500.0, "unit": "u", "what": "Crouch box width"},
	{"group": "hitbox", "key": "crouch_bottom", "tid": "T-18", "type": FLOAT, "min": -500.0, "max": 500.0, "unit": "u", "what": "Crouch box bottom, from the body origin"},
	{"group": "hitbox", "key": "crouch_top", "tid": "T-18", "type": FLOAT, "min": -500.0, "max": 500.0, "unit": "u", "what": "Crouch box top, from the body origin"},
	# Surfaces: the classic's contact bounce and friction. No T-ID yet.
	{"group": "surfaces", "key": "toy_bounce_idle", "tid": "", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "ratio", "what": "Toy bounce with the move stick let go"},
	{"group": "surfaces", "key": "toy_friction_idle", "tid": "", "type": FLOAT, "min": 0.0, "max": 2.0, "unit": "ratio", "what": "Toy friction with the move stick let go"},
	{"group": "surfaces", "key": "toy_bounce_walking", "tid": "", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "ratio", "what": "Toy bounce while walking"},
	{"group": "surfaces", "key": "toy_friction_walking", "tid": "", "type": FLOAT, "min": 0.0, "max": 2.0, "unit": "ratio", "what": "Toy friction while walking"},
	{"group": "surfaces", "key": "toy_bounce_flying", "tid": "", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "ratio", "what": "Toy bounce while flying"},
	{"group": "surfaces", "key": "toy_friction_flying", "tid": "", "type": FLOAT, "min": 0.0, "max": 2.0, "unit": "ratio", "what": "Toy friction while flying"},
	{"group": "surfaces", "key": "terrain_bounce", "tid": "", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "ratio", "what": "Terrain bounce; a contact bounces by toy × terrain"},
	{"group": "surfaces", "key": "terrain_friction", "tid": "", "type": FLOAT, "min": 0.0, "max": 2.0, "unit": "ratio", "what": "Terrain friction; a contact rubs by toy × terrain"},
	{"group": "surfaces", "key": "bounce_min_speed", "tid": "", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "u/s", "what": "Contacts slower than this into the surface do not bounce, so resting toys stay put"},
	# Battery (T-20 to T-29)
	{"group": "battery", "key": "battery_full", "tid": "T-20", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "charge", "what": "Full battery, unless the map or a modifier sets its own"},
	{"group": "battery", "key": "drain_rate", "tid": "T-21", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "charge/s", "what": "Drain flying straight up"},
	{"group": "battery", "key": "drain_floor_share", "tid": "T-21", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "share", "what": "Drain share with the stick level; straight up drains the full rate"},
	{"group": "battery", "key": "refill_pause", "tid": "T-22", "type": FLOAT, "min": 0.0, "max": 60.0, "unit": "s", "what": "Pause after thrust stops before refilling"},
	{"group": "battery", "key": "refill_rate", "tid": "T-23", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "charge/s", "what": "Refill rate"},
	# Health (T-30 to T-39), only what R0 uses
	{"group": "health", "key": "max_health", "tid": "T-30", "type": FLOAT, "min": 1.0, "max": 10000.0, "unit": "HP", "what": "Max health and health on spawn"},
	# Controls and camera (T-80 to T-89), plus the blast shake the camera applies (T-63)
	{"group": "camera", "key": "anchor_below_middle", "tid": "T-84", "type": FLOAT, "min": -1000.0, "max": 1000.0, "unit": "points", "what": "The toy body sits this far below the middle of the screen"},
	{"group": "camera", "key": "view_height", "tid": "T-88", "type": FLOAT, "min": 50.0, "max": 5000.0, "unit": "u", "what": "World height a 16:9 screen shows at 1X; other shapes see the same area"},
	{"group": "camera", "key": "zoom_scale_1", "tid": "T-80", "type": FLOAT, "min": 0.05, "max": 4.0, "unit": "scale", "what": "View scale at zoom 1X; lower shows more map"},
	{"group": "camera", "key": "zoom_scale_2", "tid": "T-80", "type": FLOAT, "min": 0.05, "max": 4.0, "unit": "scale", "what": "View scale at zoom 2X; lower shows more map"},
	{"group": "camera", "key": "zoom_scale_3", "tid": "T-80", "type": FLOAT, "min": 0.05, "max": 4.0, "unit": "scale", "what": "View scale at zoom 3X; lower shows more map"},
	{"group": "camera", "key": "zoom_scale_4", "tid": "T-80", "type": FLOAT, "min": 0.05, "max": 4.0, "unit": "scale", "what": "View scale at zoom 4X; lower shows more map"},
	{"group": "camera", "key": "zoom_scale_5", "tid": "T-80", "type": FLOAT, "min": 0.05, "max": 4.0, "unit": "scale", "what": "View scale at zoom 5X; lower shows more map"},
	{"group": "camera", "key": "zoom_scale_6", "tid": "T-80", "type": FLOAT, "min": 0.05, "max": 4.0, "unit": "scale", "what": "View scale at zoom 6X; lower shows more map"},
	{"group": "camera", "key": "zoom_scale_7", "tid": "T-80", "type": FLOAT, "min": 0.05, "max": 4.0, "unit": "scale", "what": "View scale at zoom 7X; lower shows more map"},
	{"group": "camera", "key": "look_ahead", "tid": "T-81", "type": FLOAT, "min": 0.0, "max": 2.0, "unit": "share", "what": "Aim look-ahead share of (W/4, H/4), the player's default"},
	{"group": "camera", "key": "look_ahead_floor", "tid": "T-81", "type": FLOAT, "min": 0.0, "max": 2.0, "unit": "factor", "what": "Least weapon look-ahead factor"},
	{"group": "camera", "key": "look_ahead_bare", "tid": "T-81", "type": FLOAT, "min": 0.0, "max": 2.0, "unit": "factor", "what": "Look-ahead factor with no gun"},
	{"group": "camera", "key": "panning_speed", "tid": "T-82", "type": FLOAT, "min": 0.0, "max": 100.0, "unit": "/s", "what": "Look-ahead panning speed, the player's default"},
	{"group": "camera", "key": "zoom_speed", "tid": "T-83", "type": FLOAT, "min": 0.0, "max": 100.0, "unit": "/s", "what": "Zoom easing speed, 0 snaps; the player's default"},
	{"group": "camera", "key": "stick_radius", "tid": "T-85", "type": FLOAT, "min": 5.0, "max": 500.0, "unit": "points", "what": "Stick radius at size 1"},
	{"group": "camera", "key": "stick_capture", "tid": "T-85", "type": FLOAT, "min": 5.0, "max": 1000.0, "unit": "points", "what": "A touch starting this close to a stick goes to it"},
	{"group": "camera", "key": "knob_return", "tid": "T-85", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "share", "what": "Share of the way home the let-go knob moves per 1/60 s"},
	{"group": "camera", "key": "radar_range", "tid": "T-87", "type": FLOAT, "min": 0.0, "max": 100000.0, "unit": "u", "what": "Radar arrows for off-screen toys within this range"},
	{"group": "camera", "key": "radar_speed", "tid": "T-87", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u/s", "what": "Radar shows toys moving faster than this"},
	{"group": "camera", "key": "radar_ring", "tid": "T-87", "type": FLOAT, "min": 0.05, "max": 1.0, "unit": "share", "what": "Radar ring radius as a share of screen height"},
	{"group": "camera", "key": "radar_margin", "tid": "T-87", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "u", "what": "A toy this far outside the view still counts as on screen"},
	{"group": "camera", "key": "shake_reach", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u", "what": "Blast shake reaches this far per unit of power"},
	{"group": "camera", "key": "shake_peak_reach", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u", "what": "Shake strength is (this x power - d) x power x scale"},
	{"group": "camera", "key": "shake_scale", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 10.0, "unit": "u/u", "what": "Shake strength scale"},
	{"group": "camera", "key": "shake_min", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 100.0, "unit": "u", "what": "Least shake inside the reach"},
	# Modifiers (01_world "Rulesets"): host options that change the ruleset for one match
	{"group": "modifiers", "key": "batteries_included", "tid": "", "type": BOOL, "min": 0.0, "max": 1.0, "unit": "flag", "what": "Batteries Included: every toy's battery stays full (US-02.10)"},
	{"group": "modifiers", "key": "battery_size", "tid": "T-20", "type": FLOAT, "min": -1.0, "max": 10000.0, "unit": "charge", "what": "Battery size for this match; -1 keeps the map's or the ruleset's"},
]


static func fields_in(group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in FIELDS:
		if f.group == group:
			out.append(f)
	return out


static func field(key: String) -> Dictionary:
	for f: Dictionary in FIELDS:
		if f.key == key:
			return f
	return {}


## "movement.walk_gravity (T-1)" for messages.
static func label(f: Dictionary) -> String:
	var tid: String = f.tid
	return "%s.%s%s" % [f.group, f.key, (" (%s)" % tid) if tid != "" else ""]
