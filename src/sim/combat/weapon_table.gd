class_name WeaponTable
extends RefCounted
## The weapon table (T-50) and the spawn kit (US-07.2), read from a ruleset's `weapons.cfg`.
##
## One section per weapon; the section name is the weapon id. The reserved `[spawn_kit]`
## section lists what a toy spawns with. Every field is checked against `FIELDS`; a bad row
## is refused with the weapon and the field named (US-43.2).

const FILE := "weapons.cfg"
const KIT := "spawn_kit"
const KINDS: Array[StringName] = [WeaponDef.BULLET, WeaponDef.ROCKET, WeaponDef.MELEE]
## The zoom ladder's levels (T-80): 1X to 7X.
const ZOOM_TOP := 7
## Grenade types the sim knows. Launch ships the frag (sources #24).
const GRENADES: Array[StringName] = [&"frag"]

const FLOAT := TYPE_FLOAT
const INT := TYPE_INT
const BOOL := TYPE_BOOL

## key, type, min, max, unit
const FIELDS: Array[Dictionary] = [
	{"key": "damage", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP"},
	{"key": "pellets", "type": INT, "min": 1, "max": 100, "unit": "bullets"},
	{"key": "spread", "type": FLOAT, "min": 0.0, "max": 180.0, "unit": "degrees"},
	{"key": "interval", "type": FLOAT, "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "burst", "type": INT, "min": 1, "max": 100, "unit": "rounds"},
	{"key": "burst_gap", "type": FLOAT, "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "spin_up", "type": FLOAT, "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "mag", "type": INT, "min": 0, "max": 100000, "unit": "rounds"},
	{"key": "start_reserve", "type": INT, "min": 0, "max": 100000, "unit": "rounds"},
	{"key": "max_reserve", "type": INT, "min": 0, "max": 100000, "unit": "rounds"},
	{"key": "reload", "type": FLOAT, "min": 0.0, "max": 60.0, "unit": "s"},
	{"key": "range", "type": FLOAT, "min": 0.0, "max": 100000.0, "unit": "u"},
	{"key": "bullet_speed", "type": FLOAT, "min": 0.0, "max": 1000000.0, "unit": "u/s"},
	{"key": "look_ahead", "type": FLOAT, "min": 0.0, "max": 2.0, "unit": "factor"},
	{"key": "weight", "type": FLOAT, "min": 0.01, "max": 10.0, "unit": "factor"},
	{"key": "melee_damage", "type": FLOAT, "min": 0.0, "max": 10000.0, "unit": "HP"},
	{"key": "melee_reach", "type": FLOAT, "min": 0.0, "max": 1000.0, "unit": "u"},
	{"key": "dual", "type": BOOL, "min": 0, "max": 1, "unit": "flag"},
]

var defs: Dictionary = {}
var kit_weapons: Array[StringName] = []
var kit_grenades: Array[StringName] = []


class Result:
	extends RefCounted
	var table: WeaponTable = null
	var errors: PackedStringArray = []

	func ok() -> bool:
		return table != null and errors.is_empty()


func get_def(id: StringName) -> WeaponDef:
	return defs.get(id, null)


func has(id: StringName) -> bool:
	return defs.has(id)


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in defs:
		out.append(k)
	return out


static func load_file(path: String) -> Result:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(path):
		var r := Result.new()
		r.errors.append("%s: file missing" % path)
		return r
	var err := cfg.load(path)
	if err != OK:
		var r := Result.new()
		r.errors.append("%s: cannot read (%s)" % [path, error_string(err)])
		return r
	return from_config(cfg)


static func from_config(cfg: ConfigFile) -> Result:
	var result := Result.new()
	var t := WeaponTable.new()
	for section: String in cfg.get_sections():
		if section == KIT:
			continue
		var d := _read_row(cfg, section, result.errors)
		if d != null:
			t.defs[d.id] = d
	if t.defs.is_empty():
		result.errors.append("weapons: no weapons")
	_read_kit(cfg, t, result.errors)
	if result.errors.is_empty():
		result.table = t
	return result


static func _read_row(cfg: ConfigFile, section: String, errors: PackedStringArray) -> WeaponDef:
	var d := WeaponDef.new()
	d.id = StringName(section)
	var before := errors.size()
	var known := ["name", "kind", "zoom"]
	for f: Dictionary in FIELDS:
		known.append(f.key)
	for key: String in cfg.get_section_keys(section):
		if not known.has(key):
			errors.append("weapons.%s.%s: unknown value" % [section, key])
	d.display_name = str(cfg.get_value(section, "name", section))
	var kind: Variant = cfg.get_value(section, "kind", null)
	if typeof(kind) != TYPE_STRING or not KINDS.has(StringName(kind)):
		errors.append("weapons.%s.kind (T-50): %s is not one of %s" % [section, var_to_str(kind), KINDS])
	else:
		d.kind = StringName(kind)
	for f: Dictionary in FIELDS:
		var lbl := "weapons.%s.%s (T-50)" % [section, f.key]
		if not cfg.has_section_key(section, f.key):
			errors.append("%s: missing" % lbl)
			continue
		var v: Variant = cfg.get_value(section, f.key)
		if f.type == BOOL:
			if typeof(v) != TYPE_BOOL:
				errors.append("%s: %s is not true or false" % [lbl, var_to_str(v)])
				continue
			d.set(f.key, v)
			continue
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
			errors.append("%s: %s is not a number" % [lbl, var_to_str(v)])
			continue
		var n := float(v)
		if is_nan(n) or is_inf(n):
			errors.append("%s: %s is not a finite number" % [lbl, var_to_str(v)])
			continue
		if f.type == INT and n != floorf(n):
			errors.append("%s: %s is not a whole number" % [lbl, var_to_str(v)])
			continue
		if n < float(f.min) or n > float(f.max):
			errors.append("%s: %s is out of range %s to %s %s" % [lbl, var_to_str(v), f.min, f.max, f.unit])
			continue
		d.set(f.key, int(n) if f.type == INT else n)
	var z: Variant = cfg.get_value(section, "zoom", null)
	var zoom_ok := typeof(z) == TYPE_ARRAY and not (z as Array).is_empty()
	if zoom_ok:
		var last := 0
		for level: Variant in z:
			if typeof(level) != TYPE_INT or int(level) < 1 or int(level) > ZOOM_TOP or int(level) <= last:
				zoom_ok = false
				break
			last = int(level)
			d.zoom.append(int(level))
	if not zoom_ok:
		errors.append("weapons.%s.zoom (T-50, T-80): %s must list rising levels from 1 to %d" % [section, var_to_str(z), ZOOM_TOP])
	if errors.size() == before:
		if d.max_reserve < d.start_reserve:
			errors.append("weapons.%s.max_reserve (T-50): must not be below start_reserve" % section)
		if d.shoots() and d.mag < 1:
			errors.append("weapons.%s.mag (T-50): a weapon that shoots needs a magazine of 1 or more" % section)
		if d.kind == WeaponDef.BULLET and (d.range <= 0.0 or d.bullet_speed <= 0.0):
			errors.append("weapons.%s.range (T-50): a bullet weapon needs a range and a bullet speed above 0" % section)
	return d if errors.size() == before else null


static func _read_kit(cfg: ConfigFile, t: WeaponTable, errors: PackedStringArray) -> void:
	if not cfg.has_section(KIT):
		errors.append("weapons.spawn_kit (US-07.2): missing")
		return
	var w: Variant = cfg.get_value(KIT, "weapons", null)
	var g: Variant = cfg.get_value(KIT, "grenades", null)
	if typeof(w) != TYPE_ARRAY or (w as Array).size() > 2:
		errors.append("weapons.spawn_kit.weapons (US-07.2): %s must list up to two weapon ids" % var_to_str(w))
	else:
		for id: Variant in w:
			if not t.defs.has(StringName(str(id))):
				errors.append("weapons.spawn_kit.weapons (US-07.2): %s is not in the table" % var_to_str(id))
			else:
				t.kit_weapons.append(StringName(str(id)))
	if typeof(g) != TYPE_ARRAY:
		errors.append("weapons.spawn_kit.grenades (US-07.2): %s must list grenade types" % var_to_str(g))
	else:
		for id: Variant in g:
			if not GRENADES.has(StringName(str(id))):
				errors.append("weapons.spawn_kit.grenades (US-07.2): %s is not a grenade type %s" % [var_to_str(id), GRENADES])
			else:
				t.kit_grenades.append(StringName(str(id)))


func to_dict() -> Dictionary:
	var out := {KIT: {"weapons": kit_weapons.map(func(s: StringName) -> String: return String(s)), "grenades": kit_grenades.map(func(s: StringName) -> String: return String(s))}}
	for id: StringName in defs:
		out[String(id)] = (defs[id] as WeaponDef).to_dict()
	return out


## The table as `weapons.cfg` text, for saving a tuned ruleset (US-37.3).
func to_cfg_text() -> String:
	var lines: PackedStringArray = ["; Weapon table (T-50), saved from a tuned ruleset.", "", "[%s]" % KIT, ""]
	lines.append("weapons=%s" % var_to_str(kit_weapons.map(func(s: StringName) -> String: return String(s))))
	lines.append("grenades=%s" % var_to_str(kit_grenades.map(func(s: StringName) -> String: return String(s))))
	for id: StringName in defs:
		var d: WeaponDef = defs[id]
		lines.append_array(["", "[%s]" % id, ""])
		lines.append("name=%s" % var_to_str(d.display_name))
		lines.append("kind=%s" % var_to_str(String(d.kind)))
		for f: Dictionary in FIELDS:
			lines.append("%s=%s" % [f.key, var_to_str(d.get(f.key))])
		lines.append("zoom=%s" % var_to_str(Array(d.zoom)))
	return "\n".join(lines) + "\n"
