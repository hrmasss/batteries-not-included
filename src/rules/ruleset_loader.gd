class_name RulesetLoader
extends RefCounted
## Reads a ruleset directory, checks every value against `RulesetSchema`, and refuses a
## ruleset that fails, naming each bad value (US-43.2, rule A4).
##
## A ruleset directory holds `ruleset.cfg` (id, name, version) and one `<group>.cfg` per
## schema group. Each group file has one `[<group>]` section of `key = value` lines.

const MANIFEST := "ruleset.cfg"
const STANDARD_DIR := "res://data/rulesets/standard"


class Result:
	extends RefCounted
	var ruleset: Ruleset = null
	var errors: PackedStringArray = []

	func ok() -> bool:
		return ruleset != null and errors.is_empty()


static func load_standard() -> Result:
	return load_dir(STANDARD_DIR)


## Loads and checks the ruleset in `dir`. On any error, `ruleset` is null.
static func load_dir(dir: String) -> Result:
	var sources := {}
	var errors: PackedStringArray = []
	for group: String in ["ruleset"] + Array(RulesetSchema.GROUPS):
		var path := dir.path_join("%s.cfg" % group)
		var cfg := ConfigFile.new()
		if not FileAccess.file_exists(path):
			errors.append("%s: file missing" % path)
			continue
		var err := cfg.load(path)
		if err != OK:
			errors.append("%s: cannot read (%s)" % [path, error_string(err)])
			continue
		sources[group] = cfg
	if not errors.is_empty():
		var failed := Result.new()
		failed.errors = errors
		return failed
	return from_configs(sources)


## Checks configs already in memory, keyed by group, plus "ruleset" for the manifest.
static func from_configs(sources: Dictionary) -> Result:
	var result := Result.new()
	var r := Ruleset.new()
	var manifest: ConfigFile = sources.get("ruleset")
	if manifest == null:
		result.errors.append("ruleset.cfg: missing")
	else:
		r.id = str(manifest.get_value("ruleset", "id", ""))
		r.name = str(manifest.get_value("ruleset", "name", ""))
		var v: Variant = manifest.get_value("ruleset", "version", -1)
		r.version = int(v) if typeof(v) == TYPE_INT else -1
		if r.id == "":
			result.errors.append("ruleset.id: missing")
		if r.version < 1:
			result.errors.append("ruleset.version: missing or not a whole number above 0")

	for group: String in RulesetSchema.GROUPS:
		var cfg: ConfigFile = sources.get(group)
		if cfg == null:
			result.errors.append("%s.cfg: missing" % group)
			continue
		for section: String in cfg.get_sections():
			if section != group:
				result.errors.append("%s.cfg: unknown section [%s]" % [group, section])
				continue
			for key: String in cfg.get_section_keys(section):
				var f := RulesetSchema.field(key)
				if f.is_empty() or f.group != group:
					result.errors.append("%s.%s: unknown value" % [group, key])
		for f: Dictionary in RulesetSchema.fields_in(group):
			var problem := _check(cfg, f)
			if problem != "":
				result.errors.append(problem)
			else:
				r.set(f.key, _coerce(cfg.get_value(group, f.key), f.type))

	_check_relations(r, result.errors)
	if result.errors.is_empty():
		result.ruleset = r
	return result


static func _check(cfg: ConfigFile, f: Dictionary) -> String:
	var lbl := RulesetSchema.label(f)
	if not cfg.has_section_key(f.group, f.key):
		return "%s: missing" % lbl
	var v: Variant = cfg.get_value(f.group, f.key)
	if f.type == TYPE_BOOL:
		if typeof(v) != TYPE_BOOL:
			return "%s: %s is not true or false" % [lbl, var_to_str(v)]
		return ""
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return "%s: %s is not a number" % [lbl, var_to_str(v)]
	var n := float(v)
	if is_nan(n) or is_inf(n):
		return "%s: %s is not a finite number" % [lbl, var_to_str(v)]
	if n < f.min or n > f.max:
		return "%s: %s is out of range %s to %s %s" % [lbl, var_to_str(v), f.min, f.max, f.unit]
	return ""


static func _coerce(v: Variant, type: int) -> Variant:
	if type == TYPE_BOOL:
		return bool(v)
	return float(v)


## Checks that need two values at once.
static func _check_relations(r: Ruleset, errors: PackedStringArray) -> void:
	var have := func(keys: Array) -> bool:
		for k: String in keys:
			for e: String in errors:
				if e.contains(".%s" % k):
					return false
		return true
	if have.call(["brake_full_below", "brake_none_above"]) and r.brake_none_above <= r.brake_full_below:
		errors.append("movement.brake_none_above (T-9): must be above brake_full_below")
	if have.call(["crouch_start_down", "crouch_hold_down"]) and r.crouch_hold_down > r.crouch_start_down:
		errors.append("movement.crouch_hold_down (T-16): must not be above crouch_start_down")
	if have.call(["body_bottom", "body_top"]) and r.body_top <= r.body_bottom:
		errors.append("hitbox.body_top (T-18): must be above body_bottom")
	if have.call(["crouch_bottom", "crouch_top"]) and r.crouch_top <= r.crouch_bottom:
		errors.append("hitbox.crouch_top (T-18): must be above crouch_bottom")


## Writes `r` as a ruleset directory, with each value's tuning name in a comment (US-37.3).
static func save_dir(r: Ruleset, dir: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return err
	var manifest := "[ruleset]\n\nid=%s\nname=%s\nversion=%d\n" % [var_to_str(r.id), var_to_str(r.name), r.version]
	err = _write(dir.path_join(MANIFEST), manifest)
	if err != OK:
		return err
	for group: String in RulesetSchema.GROUPS:
		var lines: PackedStringArray = ["[%s]" % group, ""]
		for f: Dictionary in RulesetSchema.fields_in(group):
			var tid: String = f.tid if f.tid != "" else "no T-ID yet"
			lines.append("; %s. %s, %s" % [tid, f.what, f.unit])
			lines.append("%s=%s" % [f.key, var_to_str(r.get(f.key))])
		err = _write(dir.path_join("%s.cfg" % group), "\n".join(lines) + "\n")
		if err != OK:
			return err
	return OK


static func _write(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	return OK
