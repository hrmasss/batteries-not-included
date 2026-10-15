extends GutTest
## Rules A1, A3 and A4 for bots and match rules, as for movement and combat: no device input,
## no frame stepping, no tuning numbers. Bot values live in bots.cfg, match values in match.cfg.

const DIRS := ["res://src/sim/bots", "res://src/sim/match"]
## Files that hold ranges, not tuning: the table reader.
const SCHEMA := ["bot_skills.gd"]
const ALLOWED := {
	"match_config.gd": ["SIDES := 2"],
	"bot.gd": ["STICK_JUMP := Vector2(0.0, 1.0)", "STICK_LAND_DOWN := -0.25", "UNSTICK_TIME := 0.6", "MIN_MISSING := 1.0", "REPLAN := 0.5", "TWO := 2.0", "HALF := 0.5"],
	"nav_grid.gd": ["MARGIN := 4.0", "LOOK_AHEAD := 8", "SNAP_RADIUS := 3", "EPSILON := 1e-6", "Vector2(0.5, 0.5)", "* 0.5"],
}


func _code_only(text: String) -> String:
	var lines: PackedStringArray = []
	for line in text.split("\n"):
		var cut := line.find("#")
		lines.append(line.substr(0, cut) if cut >= 0 else line)
	var re := RegEx.create_from_string("\"[^\"]*\"")
	return re.sub("\n".join(lines), "\"\"", true)


func _files() -> PackedStringArray:
	var out: PackedStringArray = []
	for d: String in DIRS:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				out.append(d.path_join(f))
	return out


func test_a1_a3_no_input_no_frame_stepping() -> void:
	for path in _files():
		var code := _code_only(FileAccess.get_file_as_string(path))
		for banned in ["\\bInput\\.", "\\bInputEvent", "_input\\(", "get_viewport\\(", "Camera2D", "func _process\\(", "func _physics_process\\(", "func _draw\\("]:
			assert_null(RegEx.create_from_string(banned).search(code), "%s uses %s" % [path, banned])


func test_a4_no_tuning_numbers() -> void:
	var number := RegEx.create_from_string("(?<![\\w.])\\d+(\\.\\d+)?(e-?\\d+)?(?![\\w])")
	for path in _files():
		var f := path.get_file()
		if SCHEMA.has(f):
			continue
		var code := _code_only(FileAccess.get_file_as_string(path))
		for c: String in ALLOWED.get(f, []):
			assert_true(code.contains(c), "%s still declares %s" % [f, c])
			code = code.replace(c, "")
		var bad: Array = []
		for m in number.search_all(code):
			if float(m.get_string()) != 0.0 and float(m.get_string()) != 1.0:
				bad.append(m.get_string())
		assert_eq(bad, [], "%s has number literals beyond 0 and 1" % f)
