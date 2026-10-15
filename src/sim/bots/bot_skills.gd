class_name BotSkills
extends RefCounted
## The bot skill levels (T-95 to T-97), read from a ruleset's `bots.cfg`.
##
## `[levels]` lists the level ids easiest first. `[shared]` holds values every level uses; each
## level's section may override any of them. Every value of every level must end up set and in
## range, or the ruleset is refused with the level and the value named (US-43.2).

const FILE := "bots.cfg"
const LEVELS := "levels"
const SHARED := "shared"

## key, tid, min, max, unit. Ranges only; the values live in the data.
const FIELDS: Array[Dictionary] = [
	{"key": "look_interval", "tid": "", "min": 0.0, "max": 5.0, "unit": "s"},
	{"key": "think_interval", "tid": "", "min": 0.0, "max": 5.0, "unit": "s"},
	{"key": "memory", "tid": "", "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "wander_min", "tid": "", "min": 0.0, "max": 600.0, "unit": "s"},
	{"key": "wander_max", "tid": "", "min": 0.0, "max": 600.0, "unit": "s"},
	{"key": "stuck_time", "tid": "", "min": 0.1, "max": 60.0, "unit": "s"},
	{"key": "stuck_distance", "tid": "", "min": 0.0, "max": 1000.0, "unit": "u"},
	{"key": "battery_low", "tid": "", "min": 0.0, "max": 1.0, "unit": "share"},
	{"key": "battery_resume", "tid": "", "min": 0.0, "max": 1.0, "unit": "share"},
	{"key": "cruise_share", "tid": "", "min": 0.0, "max": 1.0, "unit": "share"},
	{"key": "arrive", "tid": "", "min": 1.0, "max": 1000.0, "unit": "u"},
	{"key": "steer_gain", "tid": "", "min": 0.0, "max": 100.0, "unit": "/s"},
	{"key": "reach", "tid": "", "min": 1.0, "max": 500.0, "unit": "u"},
	{"key": "fight_share", "tid": "", "min": 0.0, "max": 1.0, "unit": "share"},
	{"key": "fight_min", "tid": "", "min": 0.0, "max": 5000.0, "unit": "u"},
	{"key": "fight_max", "tid": "", "min": 0.0, "max": 5000.0, "unit": "u"},
	{"key": "strafe", "tid": "", "min": 0.0, "max": 1000.0, "unit": "u"},
	{"key": "strafe_min", "tid": "", "min": 0.01, "max": 60.0, "unit": "s"},
	{"key": "strafe_max", "tid": "", "min": 0.01, "max": 60.0, "unit": "s"},
	{"key": "melee_range", "tid": "", "min": 0.0, "max": 500.0, "unit": "u"},
	{"key": "grenade_min", "tid": "", "min": 0.0, "max": 5000.0, "unit": "u"},
	{"key": "grenade_max", "tid": "", "min": 0.0, "max": 5000.0, "unit": "u"},
	{"key": "grenade_land_share", "tid": "", "min": 0.0, "max": 1.0, "unit": "share"},
	{"key": "grenade_mate_gap", "tid": "", "min": 0.0, "max": 5000.0, "unit": "u"},
	{"key": "throw_aim_time", "tid": "", "min": 0.0, "max": 10.0, "unit": "s"},
	{"key": "frag_value", "tid": "", "min": 0.0, "max": 1.0, "unit": "worth"},
	{"key": "cover_tries", "tid": "", "min": 1.0, "max": 100.0, "unit": "places"},
	{"key": "want_health", "tid": "", "min": 0.0, "max": 1.0, "unit": "share"},
	{"key": "retreat_health", "tid": "", "min": 0.0, "max": 1.0, "unit": "share"},
	{"key": "reload_share", "tid": "", "min": 0.0, "max": 1.0, "unit": "share"},
	{"key": "eye_height", "tid": "T-95", "min": -500.0, "max": 500.0, "unit": "u"},
	{"key": "nav_cell", "tid": "", "min": 8.0, "max": 256.0, "unit": "u"},
	{"key": "air_cost", "tid": "", "min": 0.0, "max": 100.0, "unit": "extra cost"},
	{"key": "sight", "tid": "T-95", "min": 0.0, "max": 100000.0, "unit": "u"},
	{"key": "reaction", "tid": "T-95", "min": 0.0, "max": 10.0, "unit": "s"},
	{"key": "turn_rate", "tid": "T-96", "min": 0.0, "max": 100000.0, "unit": "°/s"},
	{"key": "turn_gain", "tid": "T-96", "min": 0.0, "max": 1000.0, "unit": "/s"},
	{"key": "aim_dead_zone", "tid": "T-96", "min": 0.0, "max": 180.0, "unit": "°"},
	{"key": "aim_error", "tid": "T-96", "min": 0.0, "max": 180.0, "unit": "°"},
	{"key": "aim_wobble", "tid": "T-96", "min": 0.01, "max": 60.0, "unit": "s"},
	{"key": "lead", "tid": "T-96", "min": 0.0, "max": 2.0, "unit": "share"},
	{"key": "fire_cone", "tid": "T-97", "min": 0.0, "max": 180.0, "unit": "°"},
	{"key": "first_wait", "tid": "T-97", "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "first_burst", "tid": "T-97", "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "wait_min", "tid": "T-97", "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "wait_max", "tid": "T-97", "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "burst_min", "tid": "T-97", "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "burst_max", "tid": "T-97", "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "grenade_cooldown", "tid": "", "min": 0.0, "max": 600.0, "unit": "s"},
]
## Pairs that must not run backwards.
const PAIRS: Array = [
	["wander_min", "wander_max"], ["battery_low", "battery_resume"], ["fight_min", "fight_max"],
	["grenade_min", "grenade_max"], ["strafe_min", "strafe_max"], ["wait_min", "wait_max"], ["burst_min", "burst_max"],
	["retreat_health", "want_health"],
]

## Level ids, easiest first.
var order: Array[StringName] = []
var levels: Dictionary = {}


class Result:
	extends RefCounted
	var table: BotSkills = null
	var errors: PackedStringArray = []

	func ok() -> bool:
		return table != null and errors.is_empty()


func get_level(id: StringName) -> BotSkill:
	return levels.get(id, null)


func has(id: StringName) -> bool:
	return levels.has(id)


## The middle level, the one a fresh bootcamp offers.
func default_id() -> StringName:
	return order[order.size() / 2] if not order.is_empty() else &""


static func from_config(cfg: ConfigFile) -> Result:
	var result := Result.new()
	var t := BotSkills.new()
	var listed: Variant = cfg.get_value(LEVELS, "order", null)
	if typeof(listed) != TYPE_ARRAY or (listed as Array).is_empty():
		result.errors.append("bots.levels.order (T-95): %s must list the level ids, easiest first" % var_to_str(listed))
		return result
	var known := {}
	for f: Dictionary in FIELDS:
		known[f.key] = true
	for section: String in cfg.get_sections():
		if section == LEVELS:
			continue
		if section != SHARED and not (listed as Array).has(section):
			result.errors.append("bots.%s: a level not listed in [levels] order" % section)
			continue
		for key: String in cfg.get_section_keys(section):
			if not known.has(key):
				result.errors.append("bots.%s.%s: unknown value" % [section, key])
	for id: Variant in listed:
		var level := String(id)
		if not cfg.has_section(level):
			result.errors.append("bots.%s: level listed but missing" % level)
			continue
		var s := BotSkill.new()
		s.id = StringName(level)
		var before := result.errors.size()
		for f: Dictionary in FIELDS:
			var lbl := "bots.%s.%s%s" % [level, f.key, (" (%s)" % f.tid) if f.tid != "" else ""]
			var v: Variant = null
			if cfg.has_section_key(level, f.key):
				v = cfg.get_value(level, f.key)
			elif cfg.has_section_key(SHARED, f.key):
				v = cfg.get_value(SHARED, f.key)
			if v == null:
				result.errors.append("%s: missing" % lbl)
				continue
			if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
				result.errors.append("%s: %s is not a number" % [lbl, var_to_str(v)])
				continue
			var n := float(v)
			if is_nan(n) or is_inf(n) or n < float(f.min) or n > float(f.max):
				result.errors.append("%s: %s is out of range %s to %s %s" % [lbl, var_to_str(v), f.min, f.max, f.unit])
				continue
			s.set(f.key, n)
		if result.errors.size() == before:
			for p: Array in PAIRS:
				var lo: Variant = s.get(StringName(p[0]))
				var hi: Variant = s.get(StringName(p[1]))
				if lo == null or hi == null:
					result.errors.append("bots.%s: no value pair %s" % [level, p])
				elif float(hi) < float(lo):
					result.errors.append("bots.%s.%s: must not be below %s" % [level, p[1], p[0]])
		t.order.append(s.id)
		t.levels[s.id] = s
	if result.errors.is_empty():
		result.table = t
	return result


func to_dict() -> Dictionary:
	var out := {"order": order.map(func(s: StringName) -> String: return String(s))}
	for id: StringName in order:
		out[String(id)] = (levels[id] as BotSkill).to_dict()
	return out


## The table as `bots.cfg` text, every value written out per level, for saving a tuned ruleset.
func to_cfg_text() -> String:
	var lines: PackedStringArray = ["; Bot skill levels (T-95 to T-97), saved from a tuned ruleset.", "", "[%s]" % LEVELS, ""]
	lines.append("order=%s" % var_to_str(order.map(func(s: StringName) -> String: return String(s))))
	for id: StringName in order:
		var s: BotSkill = levels[id]
		lines.append_array(["", "[%s]" % id, ""])
		for f: Dictionary in FIELDS:
			lines.append("%s=%s" % [f.key, var_to_str(s.get(f.key))])
	return "\n".join(lines) + "\n"
