extends GutTest
## US-43.1 and US-43.2, rule A4: every tuning value is data, and a bad ruleset is refused with
## the value named.

const STANDARD := "res://data/rulesets/standard"


func _configs() -> Dictionary:
	var out := {}
	for group: String in ["ruleset"] + Array(RulesetSchema.GROUPS):
		var cfg := ConfigFile.new()
		assert_eq(cfg.load(STANDARD.path_join("%s.cfg" % group)), OK, "reads %s.cfg" % group)
		out[group] = cfg
	return out


func test_standard_ruleset_loads() -> void:
	var res := RulesetLoader.load_standard()
	assert_eq(res.errors, PackedStringArray(), "no errors")
	assert_not_null(res.ruleset)
	assert_eq(res.ruleset.id, "standard")


func test_us43_1_every_schema_value_comes_from_the_file() -> void:
	# Every field of the schema exists on Ruleset, and every Ruleset field is in the schema.
	var r := Ruleset.new()
	var props := {}
	for p: Dictionary in r.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			props[p.name] = true
	for f: Dictionary in RulesetSchema.FIELDS:
		assert_true(props.has(f.key), "Ruleset has %s" % f.key)
		props.erase(f.key)
	for meta: String in ["id", "name", "version", "weapons"]:
		props.erase(meta)
	assert_eq(props.keys(), [], "no Ruleset field outside the schema")


func test_us43_1_standard_values_match_04_tuning_start_values() -> void:
	# The start values of 04_tuning, checked once here so a drift in the data file is a choice.
	var r := RulesetLoader.load_standard().ruleset
	var expected := {
		"walk_gravity": 300.0, "fly_gravity": 50.0, "walk_speed": 190.0, "walk_catch_up": 3.0,
		"fly_speed": 300.0, "fly_catch_up": 1.5, "speed_kept_per_second": 0.55, "top_speed": 600.0,
		"brake_full_below": 20.0, "brake_none_above": 60.0, "brake_rate": 50.0, "jump_speed": 220.0,
		"jump_stick_up": 0.75, "jump_cooldown": 0.5, "jump_ground_grace": 0.25, "engage_airtime": 0.5,
		"engage_deflection": 0.75, "engage_up": 0.5, "landing_cutoff_speed": 75.0,
		"crouch_start_down": 0.75, "crouch_hold_down": 0.5, "stand_up_delay": 0.2,
		"lean_facing_flying": 0.93, "lean_facing_ground": 0.6, "offhand_weight_share": 0.5,
		"body_width": 24.0, "body_bottom": -15.0, "body_top": 5.0, "head_radius": 10.5, "head_height": 14.0,
		"battery_full": 100.0, "drain_rate": 21.0, "drain_floor_share": 0.5, "refill_pause": 1.0,
		"refill_rate": 10.0, "max_health": 100.0,
	}
	for key: String in expected:
		assert_eq(r.get(key), expected[key], key)


func test_us43_1_every_tuning_name_is_in_a_comment() -> void:
	# The data files name each value's T-ID next to it.
	for f: Dictionary in RulesetSchema.FIELDS:
		if f.tid == "":
			continue
		var text := FileAccess.get_file_as_string(STANDARD.path_join("%s.cfg" % f.group))
		assert_true(text.contains(f.tid), "%s.cfg mentions %s for %s" % [f.group, f.tid, f.key])


func test_us43_2_missing_value_is_refused_and_named() -> void:
	var c := _configs()
	(c.movement as ConfigFile).erase_section_key("movement", "jump_speed")
	var res := RulesetLoader.from_configs(c)
	assert_null(res.ruleset, "refused")
	assert_eq(res.errors, PackedStringArray(["movement.jump_speed (T-10): missing"]))


func test_us43_2_out_of_range_value_is_refused_and_named() -> void:
	var c := _configs()
	(c.battery as ConfigFile).set_value("battery", "drain_rate", -21.0)
	var res := RulesetLoader.from_configs(c)
	assert_null(res.ruleset)
	assert_eq(res.errors.size(), 1)
	assert_string_contains(res.errors[0], "battery.drain_rate (T-21)")
	assert_string_contains(res.errors[0], "out of range")


func test_us43_2_wrong_type_is_refused_and_named() -> void:
	var c := _configs()
	(c.movement as ConfigFile).set_value("movement", "top_speed", "fast")
	var res := RulesetLoader.from_configs(c)
	assert_null(res.ruleset)
	assert_string_contains(res.errors[0], "movement.top_speed (T-8)")
	assert_string_contains(res.errors[0], "not a number")


func test_us43_2_unknown_value_is_refused_and_named() -> void:
	var c := _configs()
	(c.movement as ConfigFile).set_value("movement", "jump_sped", 220.0)
	var res := RulesetLoader.from_configs(c)
	assert_null(res.ruleset)
	assert_eq(res.errors, PackedStringArray(["movement.jump_sped: unknown value"]))


func test_us43_2_inconsistent_pair_is_refused() -> void:
	var c := _configs()
	(c.movement as ConfigFile).set_value("movement", "brake_none_above", 10.0)
	var res := RulesetLoader.from_configs(c)
	assert_null(res.ruleset)
	assert_string_contains(res.errors[0], "brake_none_above (T-9)")


func test_us43_2_missing_file_is_refused() -> void:
	var res := RulesetLoader.load_dir("res://data/rulesets/does_not_exist")
	assert_null(res.ruleset)
	assert_gt(res.errors.size(), 0)


func test_us43_2_every_error_is_reported_at_once() -> void:
	var c := _configs()
	(c.movement as ConfigFile).erase_section_key("movement", "fly_speed")
	(c.battery as ConfigFile).set_value("battery", "refill_rate", 1e9)
	var res := RulesetLoader.from_configs(c)
	assert_eq(res.errors.size(), 2, "both named: %s" % ", ".join(res.errors))


func test_save_and_load_round_trip() -> void:
	# US-37.3 groundwork: a saved ruleset loads back the same.
	var r := RulesetLoader.load_standard().ruleset
	r.fly_speed = 333.0
	var dir := "user://test_ruleset_roundtrip"
	assert_eq(RulesetLoader.save_dir(r, dir), OK)
	var back := RulesetLoader.load_dir(dir)
	assert_eq(back.errors, PackedStringArray())
	assert_eq(back.ruleset.to_dict(), r.to_dict())
