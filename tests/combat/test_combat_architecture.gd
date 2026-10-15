extends GutTest
## Rules A1, A3 and A4 for the combat code, as the foundation's architecture test checks them
## for the movement code: no device input, no frame stepping, no tuning numbers.

const DIR := "res://src/sim/combat"
## Files that hold ranges or solver constants, not tuning. The schema's ranges live in the table.
const SCHEMA := ["weapon_table.gd"]
const ALLOWED := {
	"fighter.gd": ["SLOTS := 2"],
	"combat_sim.gd": ["SURFACE_GAP := 0.5", "REST_SPEED := 1.0", "TIME_EPSILON := 0.000001"],
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
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".gd"):
			out.append(f)
	return out


func test_a1_a3_no_input_no_frame_stepping() -> void:
	for f in _files():
		var code := _code_only(FileAccess.get_file_as_string(DIR.path_join(f)))
		for banned in ["\\bInput\\.", "\\bInputEvent", "_input\\(", "get_viewport\\(", "Camera2D", "func _process\\(", "func _physics_process\\(", "func _draw\\("]:
			assert_null(RegEx.create_from_string(banned).search(code), "%s uses %s" % [f, banned])


func test_a4_no_tuning_numbers() -> void:
	var number := RegEx.create_from_string("(?<![\\w.])\\d+(\\.\\d+)?(e-?\\d+)?(?![\\w])")
	for f in _files():
		if SCHEMA.has(f):
			continue
		var code := _code_only(FileAccess.get_file_as_string(DIR.path_join(f)))
		for c: String in ALLOWED.get(f, []):
			assert_true(code.contains(c), "%s still declares %s" % [f, c])
			code = code.replace(c, "")
		var bad: Array = []
		for m in number.search_all(code):
			if float(m.get_string()) != 0.0 and float(m.get_string()) != 1.0:
				bad.append(m.get_string())
		assert_eq(bad, [], "%s has number literals beyond 0 and 1" % f)
