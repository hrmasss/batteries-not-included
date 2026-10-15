extends GutTest
## US-42.1/.2 (settings kept on the phone, out-of-range values clamped), the camera defaults
## coming from the ruleset, and touch driving the match end to end (US-23.2 through the sim).

const PATH := "user://test_settings.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_us42_2_settings_survive_a_save_and_load() -> void:
	var s := ControlSettings.new()
	s.stick_size = 1.4
	s.left_handed = true
	s.floating_sticks = true
	s.invert_aim = 2
	s.fire_button = true
	s.look_ahead = 0.5
	s.zoom_mode = ControlSettings.ZoomMode.WIDEST
	s.shake = 0.3
	s.volume_music = 0.2
	assert_eq(s.save(PATH), OK)
	var back := ControlSettings.load_or_default(PATH)
	assert_almost_eq(back.stick_size, 1.4, 1e-6)
	assert_true(back.left_handed)
	assert_true(back.floating_sticks)
	assert_eq(back.invert_aim, 2)
	assert_true(back.fire_button)
	assert_almost_eq(back.look_ahead, 0.5, 1e-6)
	assert_eq(back.zoom_mode, ControlSettings.ZoomMode.WIDEST)
	assert_almost_eq(back.shake, 0.3, 1e-6)
	assert_almost_eq(back.volume_music, 0.2, 1e-6)


func test_us42_2_an_old_or_odd_file_still_loads() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "stick_size", 9)
	cfg.set_value("settings", "opacity", "lots")
	cfg.set_value("settings", "from_the_future", true)
	cfg.save(PATH)
	var s := ControlSettings.load_or_default(PATH)
	assert_almost_eq(s.stick_size, 2.0, 1e-6, "clamped, and an int read as a float")
	assert_almost_eq(s.opacity, ControlSettings.new().opacity, 1e-6, "wrong type keeps the default")


func test_camera_defaults_come_from_the_ruleset() -> void:
	var r := TestWorld.rules()
	r.panning_speed = 4.0
	var v := ViewRules.from_ruleset(r)
	var s := ControlSettings.new()
	assert_almost_eq(s.effective_panning(v), 4.0, 1e-6)
	s.panning_speed = 8.0
	assert_almost_eq(s.effective_panning(v), 8.0, 1e-6, "the player's own wins once set")


func test_touch_drives_the_toy_through_the_match() -> void:
	var rules := TestWorld.rules()
	var sim := TestWorld.sim(self, rules)
	autofree(sim)
	var toy := sim.spawn_toy(0)
	Drills.settle(sim, toy)
	var tc := TouchControls.new()
	add_child_autofree(tc)
	tc.size = Vector2(640, 360)
	tc.setup(ViewRules.from_ruleset(rules), ControlSettings.new())
	var x0 := toy.position.x
	# Left thumb lands on the move stick and pushes right, then far off the stick.
	tc.touch_down(0, tc.move_stick.home)
	tc.touch_move(0, tc.move_stick.home + Vector2(tc.move_stick.radius, 0))
	for i in 60:
		var intent := InputIntent.new()
		tc.fill(intent)
		sim.step({toy.toy_id: intent})
		if i == 30:
			tc.touch_move(0, tc.move_stick.home + Vector2(400, 40))
	assert_gt(toy.position.x - x0, 60.0, "walked right")
	assert_gt(toy.velocity.x, 0.0)
	# Lift: the knob slides home and the toy stops.
	tc.touch_up(0)
	for i in 120:
		tc.move_stick.step(1.0 / 60.0)
		var intent := InputIntent.new()
		tc.fill(intent)
		sim.step({toy.toy_id: intent})
	assert_almost_eq(toy.velocity.x, 0.0, 1.0, "stopped after the thumb lifted")
