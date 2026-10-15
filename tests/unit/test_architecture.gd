extends GutTest
## Rules A1 to A4 as far as code can check them: the sim reads no device input and draws
## nothing, the view decides no rules, and the movement rules hold no tuning numbers.

const SIM_DIRS := ["res://src/sim", "res://src/rules", "res://src/maps"]
const VIEW_DIRS := ["res://src/view", "res://src/app"]


func _scripts(dirs: Array) -> Dictionary:
	var out := {}
	for dir: String in dirs:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				out[dir.path_join(file)] = FileAccess.get_file_as_string(dir.path_join(file))
	return out


func _code_only(text: String) -> String:
	# Drops comments and strings so words in docs do not count.
	var lines: PackedStringArray = []
	for line in text.split("\n"):
		var cut := line.find("#")
		lines.append(line.substr(0, cut) if cut >= 0 else line)
	var re := RegEx.create_from_string("\"[^\"]*\"")
	return re.sub("\n".join(lines), "\"\"", true)


func test_a1_sim_reads_no_device_input() -> void:
	for path: String in _scripts(SIM_DIRS):
		var code := _code_only(_scripts(SIM_DIRS)[path])
		for banned in ["\\bInput\\.", "\\bInputEvent", "\\b_input\\(", "_unhandled_input\\(", "get_viewport\\(", "Camera2D"]:
			assert_null(RegEx.create_from_string(banned).search(code), "%s uses %s" % [path, banned])


func test_a1_sim_does_not_know_the_view() -> void:
	var view_classes := []
	for path: String in _scripts(VIEW_DIRS):
		var m := RegEx.create_from_string("class_name\\s+(\\w+)").search(_scripts(VIEW_DIRS)[path])
		if m:
			view_classes.append(m.get_string(1))
	for path: String in _scripts(SIM_DIRS):
		var code := _code_only(_scripts(SIM_DIRS)[path])
		assert_false(code.contains("res://src/view"), "%s loads the view" % path)
		for cls: String in view_classes:
			assert_false(RegEx.create_from_string("\\b%s\\b" % cls).search(code) != null, "%s uses view class %s" % [path, cls])


func test_a3_sim_steps_on_its_own_clock() -> void:
	# The sim never steps from the engine's frame callbacks.
	for path: String in _scripts(["res://src/sim"]):
		var code := _code_only(_scripts(["res://src/sim"])[path])
		assert_false(code.contains("func _process("), "%s steps per frame" % path)
		assert_false(code.contains("func _physics_process("), "%s steps on the engine's physics loop" % path)


func test_a4_motor_holds_no_tuning_numbers() -> void:
	# US-43.1 for the movement rules: only 0 and 1 may appear as literals; the two solver
	# constants are named at the top of the file and listed here.
	var allowed_consts := {
		"res://src/sim/toy_motor.gd": ["SUBSTEPS := 2", "MIN_MISSING := 0.0001"],
	}
	var number := RegEx.create_from_string("(?<![\\w.])\\d+(\\.\\d+)?(e-?\\d+)?(?![\\w])")
	for path: String in allowed_consts:
		var code := _code_only(FileAccess.get_file_as_string(path))
		for c: String in allowed_consts[path]:
			assert_true(code.contains(c), "%s still declares %s" % [path, c])
			code = code.replace(c, "")
		var bad: Array = []
		for m in number.search_all(code):
			var lit := m.get_string()
			if float(lit) != 0.0 and float(lit) != 1.0:
				bad.append(lit)
		assert_eq(bad, [], "%s has number literals beyond 0 and 1" % path)
