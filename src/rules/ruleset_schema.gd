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

const GROUPS: PackedStringArray = ["movement", "hitbox", "surfaces", "battery", "health", "guns", "throwables", "match", "camera", "modifiers"]

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
	{"group": "battery", "key": "battery_pack_time", "tid": "T-24", "type": FLOAT, "min": 0.0, "max": 600.0, "unit": "s", "what": "A battery pack holds the battery full this long"},
	# Health (T-30 to T-39)
	{"group": "health", "key": "max_health", "tid": "T-30", "type": FLOAT, "min": 1.0, "max": 10000.0, "unit": "HP", "what": "Max health and health on spawn"},
	{"group": "health", "key": "regen_rate", "tid": "T-31", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "HP/s", "what": "Health regen while alive and below full, no delay after damage"},
	{"group": "health", "key": "pack_instant", "tid": "T-32", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP", "what": "Health pack: healed at once"},
	{"group": "health", "key": "pack_flow", "tid": "T-32", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP", "what": "Health pack: healed after the instant part, at the flow rate"},
	{"group": "health", "key": "pack_flow_rate", "tid": "T-32", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP/s", "what": "Health pack: flow rate of the second part"},
	{"group": "health", "key": "knockback_per_hp", "tid": "T-33", "type": FLOAT, "min": 0.0, "max": 100.0, "unit": "u/s per HP", "what": "Hit knockback speed per HP of damage, along the hit"},
	{"group": "health", "key": "knockback_cap", "tid": "T-33", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u/s", "what": "Hit knockback cap per axis"},
	{"group": "health", "key": "out_of_bounds_damage", "tid": "T-34", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP", "what": "Damage per out-of-bounds interval outside the map's bounds"},
	{"group": "health", "key": "out_of_bounds_interval", "tid": "T-34", "type": FLOAT, "min": 0.01, "max": 60.0, "unit": "s", "what": "Out-of-bounds damage interval"},
	# Guns, general (T-40 to T-49). The weapon rows (T-50) are a table of their own: WeaponTable
	{"group": "guns", "key": "headshot_factor", "tid": "T-40", "type": FLOAT, "min": 1.0, "max": 10.0, "unit": "multiplier", "what": "Headshot damage multiplier; never on a crouched target or for melee"},
	{"group": "guns", "key": "falloff_start_share", "tid": "T-41", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "share", "what": "Full damage up to this share of the range, then falls to 0.5 at max range"},
	{"group": "guns", "key": "inherit_velocity", "tid": "T-42", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "share", "what": "Share of the shooter's velocity a bullet inherits"},
	{"group": "guns", "key": "bullet_fade", "tid": "T-43", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u", "what": "Bullets fade over this last stretch of their range (drawn only)"},
	{"group": "guns", "key": "pickup_reach", "tid": "T-45", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "u", "what": "Pickup reach around the toy"},
	{"group": "guns", "key": "pickup_reach_up", "tid": "T-45", "type": FLOAT, "min": -1000.0, "max": 1000.0, "unit": "u", "what": "The pickup reach is measured from this far above the toy's centre"},
	{"group": "guns", "key": "melee_swing", "tid": "T-46", "type": FLOAT, "min": 0.01, "max": 10.0, "unit": "s", "what": "Melee swing time; the hit lands at its end"},
	{"group": "guns", "key": "lunge_meter_max", "tid": "T-46", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u/s", "what": "Lunge meter full"},
	{"group": "guns", "key": "lunge_cost", "tid": "T-46", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u/s", "what": "Lunge meter spent per swing"},
	{"group": "guns", "key": "lunge_refill", "tid": "T-46", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "per s", "what": "Lunge meter refill"},
	{"group": "guns", "key": "lunge_speed_cap", "tid": "T-46", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u/s", "what": "No lunge while faster than this × weight factor, unless moving away from the aim"},
	{"group": "guns", "key": "bare_hand_damage", "tid": "T-47", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP", "what": "Melee damage with no weapon"},
	{"group": "guns", "key": "bare_hand_reach", "tid": "", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "u", "what": "Melee reach with no weapon"},
	# Throwables and blasts (T-60 to T-69)
	{"group": "throwables", "key": "grenade_cap", "tid": "T-60", "type": FLOAT, "min": 0.0, "max": 100.0, "unit": "count", "what": "Most grenades a toy carries, all types together"},
	{"group": "throwables", "key": "throw_speed", "tid": "T-61", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u/s", "what": "Throw speed along the aim, plus the thrower's velocity"},
	{"group": "throwables", "key": "throw_offset", "tid": "T-61", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "u", "what": "A thrown grenade starts this far out from the hand"},
	{"group": "throwables", "key": "frag_fuse", "tid": "T-62", "type": FLOAT, "min": 0.0, "max": 60.0, "unit": "s", "what": "Frag fuse from the throw"},
	{"group": "throwables", "key": "frag_gravity", "tid": "T-62", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u/s²", "what": "Frag gravity, times the map's item gravity"},
	{"group": "throwables", "key": "frag_speed_kept", "tid": "T-62", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "share", "what": "Frag speed kept per second"},
	{"group": "throwables", "key": "frag_bounce", "tid": "T-62", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "ratio", "what": "Frag bounce"},
	{"group": "throwables", "key": "frag_friction", "tid": "", "type": FLOAT, "min": 0.0, "max": 2.0, "unit": "ratio", "what": "Frag friction on a bounce"},
	{"group": "throwables", "key": "frag_power", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 10.0, "unit": "power", "what": "Frag blast power"},
	{"group": "throwables", "key": "blast_radius", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u", "what": "Blast radius at power 1"},
	{"group": "throwables", "key": "blast_damage", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP", "what": "Blast damage at the centre at power 1"},
	{"group": "throwables", "key": "blast_falloff", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "HP/u", "what": "Blast damage lost per u from the centre"},
	{"group": "throwables", "key": "blast_min_damage", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP", "what": "Least blast damage inside the radius, and all a toy behind a wall takes"},
	{"group": "throwables", "key": "blast_knockback_per_hp", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "u/s per HP", "what": "Blast knockback speed per HP of damage"},
	{"group": "throwables", "key": "blast_knockback_cap", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP", "what": "Blast knockback counts at most this much damage"},
	{"group": "throwables", "key": "blast_shake_reach", "tid": "T-63", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "u", "what": "Screen shake reach at power 1"},
	{"group": "throwables", "key": "rocket_direct_damage", "tid": "T-67", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP", "what": "Rocket direct hit"},
	{"group": "throwables", "key": "rocket_arm_time", "tid": "T-67", "type": FLOAT, "min": 0.0, "max": 60.0, "unit": "s", "what": "A rocket blasts on walls only after this much flight"},
	{"group": "throwables", "key": "rocket_life", "tid": "T-67", "type": FLOAT, "min": 0.0, "max": 600.0, "unit": "s", "what": "A rocket self-destructs after this long"},
	{"group": "throwables", "key": "rocket_speed_cap", "tid": "T-67", "type": FLOAT, "min": 0.0, "max": 100000.0, "unit": "u/s", "what": "Rocket speed cap"},
	{"group": "throwables", "key": "rocket_power", "tid": "T-67", "type": FLOAT, "min": 0.0, "max": 10.0, "unit": "power", "what": "Rocket blast power"},
	{"group": "throwables", "key": "rocket_bounce", "tid": "", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "ratio", "what": "An unarmed rocket bounces off walls by this much"},
	# Match (T-68, T-70 to T-79)
	{"group": "match", "key": "respawn_wait", "tid": "T-70", "type": FLOAT, "min": 0.0, "max": 600.0, "unit": "s", "what": "Respawn wait after a pop"},
	{"group": "match", "key": "spawn_protection", "tid": "T-68", "type": FLOAT, "min": 0.0, "max": 60.0, "unit": "s", "what": "Spawn protection against everything; ends when the toy attacks"},
	{"group": "match", "key": "spawn_enemy_weight", "tid": "T-71", "type": FLOAT, "min": 0.0, "max": 100.0, "unit": "weight", "what": "Spawn score weight on distance to each living enemy"},
	{"group": "match", "key": "spawn_explosive_weight", "tid": "T-71", "type": FLOAT, "min": 0.0, "max": 100.0, "unit": "weight", "what": "Spawn score weight on distance to each live explosive"},
	{"group": "match", "key": "spawn_pick_share", "tid": "T-71", "type": FLOAT, "min": 0.01, "max": 1.0, "unit": "share", "what": "Spawns pick at random from this best share of points"},
	{"group": "match", "key": "spawn_reuse_block", "tid": "T-71", "type": FLOAT, "min": 0.0, "max": 600.0, "unit": "s", "what": "Skip spawn points used this recently"},
	{"group": "match", "key": "pickup_interval", "tid": "T-76", "type": FLOAT, "min": 0.0, "max": 3600.0, "unit": "s", "what": "Pickup point respawn interval; 0 turns map pickups off"},
	{"group": "match", "key": "floor_lifetime_lead", "tid": "T-77", "type": FLOAT, "min": 0.0, "max": 3600.0, "unit": "s", "what": "A map item lasts its interval less this"},
	{"group": "match", "key": "floor_fade", "tid": "T-77", "type": FLOAT, "min": 0.0, "max": 3600.0, "unit": "s", "what": "Items fade over the last this many s of their lifetime"},
	{"group": "match", "key": "empty_gun_lifetime", "tid": "T-77", "type": FLOAT, "min": 0.0, "max": 3600.0, "unit": "s", "what": "An empty dropped gun lasts this long"},
	{"group": "match", "key": "dropped_gun_lifetime", "tid": "", "type": FLOAT, "min": 0.0, "max": 3600.0, "unit": "s", "what": "A dropped gun with ammo left lasts this long"},
	{"group": "match", "key": "crowd_start", "tid": "T-77", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "items", "what": "Floor lifetimes start to shrink above this many items"},
	{"group": "match", "key": "crowd_full", "tid": "T-77", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "items", "what": "Floor lifetimes are shortest from this many items"},
	{"group": "match", "key": "crowd_min_share", "tid": "T-77", "type": FLOAT, "min": 0.0, "max": 1.0, "unit": "share", "what": "Shortest floor lifetime, as a share of full"},
	{"group": "match", "key": "match_length", "tid": "T-72", "type": FLOAT, "min": 1.0, "max": 3600.0, "unit": "s", "what": "Match length by default"},
	{"group": "match", "key": "match_length_min", "tid": "T-72", "type": FLOAT, "min": 1.0, "max": 3600.0, "unit": "s", "what": "Shortest match a host can set"},
	{"group": "match", "key": "match_length_max", "tid": "T-72", "type": FLOAT, "min": 1.0, "max": 3600.0, "unit": "s", "what": "Longest match a host can set"},
	{"group": "match", "key": "match_length_step", "tid": "T-72", "type": FLOAT, "min": 1.0, "max": 3600.0, "unit": "s", "what": "Match length choices go up in this step"},
	{"group": "match", "key": "kill_limit_on", "tid": "T-73", "type": BOOL, "min": 0.0, "max": 1.0, "unit": "flag", "what": "The kill limit is on by default"},
	{"group": "match", "key": "kill_limit", "tid": "T-73", "type": FLOAT, "min": 1.0, "max": 1000.0, "unit": "kills", "what": "Kills that end the match when the limit is on"},
	{"group": "match", "key": "players_max", "tid": "T-75", "type": FLOAT, "min": 2.0, "max": 64.0, "unit": "players", "what": "Most toys in a match, bots included"},
	{"group": "match", "key": "players_default", "tid": "T-75", "type": FLOAT, "min": 2.0, "max": 64.0, "unit": "players", "what": "Toys in a match by default"},
	{"group": "match", "key": "players_min", "tid": "T-75", "type": FLOAT, "min": 2.0, "max": 64.0, "unit": "players", "what": "Fewest toys a match starts with"},
	{"group": "match", "key": "teams_min", "tid": "T-78", "type": FLOAT, "min": 2.0, "max": 16.0, "unit": "teams", "what": "Fewest teams in team deathmatch"},
	{"group": "match", "key": "teams_max", "tid": "T-78", "type": FLOAT, "min": 2.0, "max": 16.0, "unit": "teams", "what": "Most teams in team deathmatch"},
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
