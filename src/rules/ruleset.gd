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
var battery_pack_time: float

# health
var max_health: float
var regen_rate: float
var pack_instant: float
var pack_flow: float
var pack_flow_rate: float
var knockback_per_hp: float
var knockback_cap: float
var out_of_bounds_damage: float
var out_of_bounds_interval: float

# guns
var headshot_factor: float
var falloff_start_share: float
var inherit_velocity: float
var bullet_fade: float
var pickup_reach: float
var pickup_reach_up: float
var melee_swing: float
var lunge_meter_max: float
var lunge_cost: float
var lunge_refill: float
var lunge_speed_cap: float
var bare_hand_damage: float
var bare_hand_reach: float

# throwables
var grenade_cap: float
var throw_speed: float
var throw_offset: float
var frag_fuse: float
var frag_gravity: float
var frag_speed_kept: float
var frag_bounce: float
var frag_friction: float
var frag_power: float
var blast_radius: float
var blast_damage: float
var blast_falloff: float
var blast_min_damage: float
var blast_knockback_per_hp: float
var blast_knockback_cap: float
var blast_shake_reach: float
var rocket_direct_damage: float
var rocket_arm_time: float
var rocket_life: float
var rocket_speed_cap: float
var rocket_power: float
var rocket_bounce: float

# match
var respawn_wait: float
var spawn_protection: float
var spawn_enemy_weight: float
var spawn_explosive_weight: float
var spawn_pick_share: float
var spawn_reuse_block: float
var pickup_interval: float
var floor_lifetime_lead: float
var floor_fade: float
var empty_gun_lifetime: float
var dropped_gun_lifetime: float
var crowd_start: float
var crowd_full: float
var crowd_min_share: float

# camera
var anchor_below_middle: float
var view_height: float
var zoom_scale_1: float
var zoom_scale_2: float
var zoom_scale_3: float
var zoom_scale_4: float
var zoom_scale_5: float
var zoom_scale_6: float
var zoom_scale_7: float
var look_ahead: float
var look_ahead_floor: float
var look_ahead_bare: float
var panning_speed: float
var zoom_speed: float
var stick_radius: float
var stick_capture: float
var knob_return: float
var radar_range: float
var radar_speed: float
var radar_ring: float
var radar_margin: float
var shake_peak_reach: float
var shake_scale: float
var shake_min: float

# weapon table (T-50) and spawn kit, from weapons.cfg
var weapons: WeaponTable

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
	r.weapons = weapons
	return r


## Plain values by key, for sending to joiners and for comparing two rulesets.
func to_dict() -> Dictionary:
	var out := {"id": id, "name": name, "version": version}
	for f: Dictionary in RulesetSchema.FIELDS:
		out[f.key] = get(f.key)
	out["weapons"] = weapons.to_dict() if weapons != null else {}
	return out
