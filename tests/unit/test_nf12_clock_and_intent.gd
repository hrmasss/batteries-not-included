extends GutTest
## NF-12 and rule A3: the fixed clock. The input intent the match accepts.


func test_nf12_clock_turns_any_frames_into_fixed_ticks() -> void:
	for fps in [24.0, 30.0, 59.94, 60.0, 90.0, 120.0, 144.0]:
		var c := SimClock.new()
		var ticks := 0
		var frames := int(fps * 10.0)
		for i in frames:
			ticks += c.advance(1.0 / fps)
		assert_almost_eq(ticks, roundi(frames / fps * SimClock.TICK_RATE), 1, "%s fps" % fps)


func test_nf12_clock_alpha_between_ticks() -> void:
	var c := SimClock.new()
	assert_eq(c.advance(SimClock.TICK * 0.5), 0)
	assert_almost_eq(c.alpha(), 0.5, 0.001)
	assert_eq(c.advance(SimClock.TICK * 0.5), 1)
	assert_almost_eq(c.alpha(), 0.0, 0.001)


func test_nf12_clock_drops_a_long_stall() -> void:
	var c := SimClock.new()
	assert_eq(c.advance(5.0), SimClock.MAX_TICKS_PER_FRAME)
	assert_eq(c.advance(SimClock.TICK), 1)


func test_intent_is_sanitized() -> void:
	var i := InputIntent.new()
	i.move = Vector2(3, 4)
	i.aim = Vector2(NAN, 1)
	i.buttons = 0xFFFF
	var s := i.sanitized()
	assert_almost_eq(s.move.length(), 1.0, 0.0001, "stick clamped to 1")
	assert_eq(s.aim, Vector2.ZERO, "non-finite aim dropped")
	assert_eq(s.buttons, 127, "unknown buttons dropped")


func test_intent_buttons_and_round_trip() -> void:
	var i := InputIntent.make(Vector2(0.5, -0.5), true, Vector2(1, 0))
	i.fire = true
	i.set_button(InputIntent.Act.GRENADE, true)
	i.set_button(InputIntent.Act.ZOOM, true)
	assert_true(i.is_down(InputIntent.Act.ZOOM))
	assert_false(i.is_down(InputIntent.Act.MELEE))
	assert_true(InputIntent.from_dict(i.to_dict()).equals(i))


func test_scripted_input_holds_each_step() -> void:
	var s := ScriptedInput.from_steps([{"t": 1.0, "move": [1, 0]}, {"t": 0.0, "move": [0, 0], "held": false}, {"t": 2.0, "held": false}])
	assert_false(s.intent_at(0.5).move_held)
	assert_eq(s.intent_at(1.0).move, Vector2(1, 0))
	assert_true(s.intent_at(1.5).move_held)
	assert_eq(s.intent_at(2.5).move, Vector2(1, 0), "fields carry over")
	assert_false(s.intent_at(2.5).move_held)
