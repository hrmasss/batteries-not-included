extends GutTest
## US-23.2 (touch capture and tracking), US-05.1 (aim at any distance), US-05.2 (fire past the
## ring), US-05.7 (separate fire button), T-85 (no dead zone, knob return), US-23.3/.4 layout.

const SCREEN := Vector2(640, 360)

var rules: Ruleset
var view_rules: ViewRules
var settings: ControlSettings


func before_each() -> void:
	rules = TestWorld.rules()
	view_rules = ViewRules.from_ruleset(rules)
	settings = ControlSettings.new()


func _controls() -> TouchControls:
	var tc := TouchControls.new()
	add_child_autofree(tc)
	tc.size = SCREEN
	tc.setup(view_rules, settings)
	return tc


func _stick() -> TouchStick:
	var s := TouchStick.new(Vector2(100, 280), view_rules.stick_radius, view_rules.stick_capture)
	s.knob_return = view_rules.knob_return
	return s


func test_us23_2_touch_near_a_stick_is_taken() -> void:
	var s := _stick()
	assert_true(s.press(3, s.home + Vector2(view_rules.stick_capture - 1.0, 0)), "inside capture distance")
	assert_eq(s.touch, 3)


func test_us23_2_touch_far_from_a_stick_is_not_taken() -> void:
	var s := _stick()
	assert_false(s.press(3, s.home + Vector2(view_rules.stick_capture + 1.0, 0)), "outside capture distance")
	assert_false(s.held())


func test_us23_2_stick_tracks_its_touch_wherever_it_goes() -> void:
	var s := _stick()
	s.press(0, s.home)
	s.drag(0, s.home + Vector2(500, -300))
	assert_true(s.held(), "still held far away")
	assert_almost_eq(s.output().length(), 1.0, 1e-4, "full deflection")
	s.drag(7, s.home + Vector2(-10, 0))
	assert_gt(s.output().x, 0.0, "another touch does not move it")
	s.release(0)
	assert_false(s.held())


func test_t85_no_dead_zone() -> void:
	var s := _stick()
	s.press(0, s.home)
	s.drag(0, s.home + Vector2(1.0, 0))
	assert_almost_eq(s.output().x, 1.0 / view_rules.stick_radius, 1e-5, "one point right reads as a small walk")


func test_t85_output_is_offset_over_radius_y_up() -> void:
	var s := _stick()
	s.press(0, s.home)
	s.drag(0, s.home + Vector2(view_rules.stick_radius * 0.5, -view_rules.stick_radius * 0.5))
	assert_almost_eq(s.output().x, 0.5, 1e-5)
	assert_almost_eq(s.output().y, 0.5, 1e-5, "screen up is stick up")


func test_t85_knob_returns_by_share_per_sixtieth() -> void:
	var s := _stick()
	s.press(0, s.home)
	s.drag(0, s.home + Vector2(view_rules.stick_radius, 0))
	s.release(0)
	s.step(1.0 / 60.0)
	assert_almost_eq(s.output().x, 1.0 - view_rules.knob_return, 1e-4, "one frame home")
	for i in 120:
		s.step(1.0 / 60.0)
	assert_eq(s.output(), Vector2.ZERO, "home after two seconds")


func test_us05_1_aims_along_thumb_angle_at_any_distance() -> void:
	var s := _stick()
	for dist: float in [3.0, 20.0, 39.0, 120.0]:
		s.press(0, s.home)
		var ang := deg_to_rad(-35.0)
		s.drag(0, s.home + Vector2(cos(ang), sin(ang)) * dist)
		var d := s.direction()
		assert_almost_eq(d.angle(), deg_to_rad(35.0), 1e-4, "angle at distance %s" % dist)
		s.release(0)


func test_us05_2_fires_only_past_the_ring() -> void:
	var tc := _controls()
	var aim := tc.aim_stick
	var r := aim.radius
	var i := InputIntent.new()
	tc.touch_down(1, aim.home + Vector2(-r * 0.5, 0))
	tc.fill(i)
	assert_false(i.fire, "inside the ring aims only")
	assert_almost_eq(i.aim.x, -1.0, 1e-5)
	tc.touch_move(1, aim.home + Vector2(-r * 1.2, 0))
	tc.fill(i)
	assert_true(i.fire, "past the ring fires")
	tc.touch_move(1, aim.home + Vector2(-r * 0.8, 0))
	tc.fill(i)
	assert_false(i.fire, "back inside stops")
	tc.touch_move(1, aim.home + Vector2(0, -r * 1.5))
	tc.fill(i)
	assert_true(i.fire)
	tc.touch_up(1)
	tc.fill(i)
	assert_false(i.fire, "lifting stops")
	assert_eq(i.aim, Vector2.ZERO, "no aim with the thumb off")


func test_us05_2_a_flick_past_the_ring_still_fires_once() -> void:
	var tc := _controls()
	var aim := tc.aim_stick
	var i := InputIntent.new()
	tc.touch_down(1, aim.home)
	tc.touch_move(1, aim.home + Vector2(aim.radius * 2.0, 0))
	tc.touch_up(1)
	tc.fill(i)
	assert_true(i.fire, "a flick between two ticks is not lost")
	tc.fill(i)
	assert_false(i.fire)


func test_us05_7_fire_button_mode_aim_stick_only_aims() -> void:
	settings.fire_button = true
	var tc := _controls()
	var aim := tc.aim_stick
	var i := InputIntent.new()
	tc.touch_down(1, aim.home + Vector2(aim.radius * 2.0, 0))
	tc.fill(i)
	assert_false(i.fire, "past the ring does not fire")
	tc.touch_down(2, tc.layout.center(TouchLayout.Id.FIRE))
	tc.fill(i)
	assert_true(i.fire, "the fire button fires")


func test_us23_2_move_and_aim_sticks_take_their_own_thumbs() -> void:
	var tc := _controls()
	var i := InputIntent.new()
	tc.touch_down(0, tc.move_stick.home + Vector2(20, 0))
	tc.touch_down(1, tc.aim_stick.home + Vector2(0, -20))
	tc.fill(i)
	assert_true(i.move_held)
	assert_gt(i.move.x, 0.0)
	assert_gt(i.aim.y, 0.9)


func test_buttons_reach_the_intent_even_when_tapped_between_ticks() -> void:
	var tc := _controls()
	var i := InputIntent.new()
	var pos := tc.layout.center(TouchLayout.Id.RELOAD)
	tc.touch_down(4, pos)
	tc.touch_up(4)
	tc.fill(i)
	assert_true(i.is_down(InputIntent.Act.RELOAD), "a tap shorter than a tick counts")
	tc.fill(i)
	assert_false(i.is_down(InputIntent.Act.RELOAD), "and only once")


func test_every_button_maps_to_its_act() -> void:
	var tc := _controls()
	tc.can_pick_up = true
	var expect := {
		TouchLayout.Id.GRENADE: InputIntent.Act.GRENADE, TouchLayout.Id.MELEE: InputIntent.Act.MELEE,
		TouchLayout.Id.RELOAD: InputIntent.Act.RELOAD, TouchLayout.Id.SWITCH: InputIntent.Act.SWITCH,
		TouchLayout.Id.PICK_UP: InputIntent.Act.PICK_UP, TouchLayout.Id.ZOOM: InputIntent.Act.ZOOM,
		TouchLayout.Id.GRENADE_SWITCH: InputIntent.Act.GRENADE_SWITCH,
	}
	for id: int in expect:
		var i := InputIntent.new()
		tc.touch_down(9, tc.layout.center(id))
		tc.fill(i)
		tc.touch_up(9)
		assert_eq(i.buttons, int(expect[id]), "button %s" % TouchLayout.Id.keys()[id])


func test_us23_1_controls_inside_the_screen_and_apart() -> void:
	for shape: Vector2 in [Vector2(640, 360), Vector2(800, 360), Vector2(640, 480)]:
		var l := TouchLayout.build(shape, settings)
		var screen := Rect2(Vector2.ZERO, shape)
		for id: int in l.centers:
			var r := l.radius(id) if l.radii.has(id) else view_rules.stick_radius
			assert_true(screen.grow(-r * 0.5).has_point(l.center(id)), "%s on screen %s" % [TouchLayout.Id.keys()[id], shape])
		for a: int in l.radii:
			for b: int in l.radii:
				if a < b and not (a == TouchLayout.Id.FIRE or b == TouchLayout.Id.FIRE):
					assert_gt(l.center(a).distance_to(l.center(b)), l.radius(a) + l.radius(b), "%s clear of %s" % [a, b])


func test_us23_4_left_handed_mirrors_everything() -> void:
	var right := TouchLayout.build(SCREEN, settings)
	settings.left_handed = true
	var left := TouchLayout.build(SCREEN, settings)
	for id: int in right.centers:
		assert_almost_eq(left.center(id).x, SCREEN.x - right.center(id).x, 1e-4)
		assert_almost_eq(left.center(id).y, right.center(id).y, 1e-4)
	assert_gt(left.center(TouchLayout.Id.MOVE).x, SCREEN.x * 0.5, "move stick on the right")


func test_us23_3_floating_stick_centres_where_the_thumb_lands() -> void:
	settings.floating_sticks = true
	var tc := _controls()
	var land := Vector2(200, 200)
	tc.touch_down(0, land)
	assert_eq(tc.move_stick.center, land)
	var i := InputIntent.new()
	tc.fill(i)
	assert_eq(i.move, Vector2.ZERO, "lands at centre, no jump")


func test_us23_5_stick_size_scales_the_stick() -> void:
	settings.stick_size = 1.5
	var tc := _controls()
	assert_almost_eq(tc.move_stick.radius, view_rules.stick_radius * 1.5, 1e-4)


func test_invert_flips_the_axes() -> void:
	var s := _stick()
	s.invert = 3
	s.press(0, s.home)
	s.drag(0, s.home + Vector2(10, -10))
	assert_lt(s.output().x, 0.0)
	assert_lt(s.output().y, 0.0)
