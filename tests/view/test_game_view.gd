extends GutTest
## The view runs the sim on the fixed clock and draws between ticks. Headless smoke test: the
## whole game scene runs scripted input without errors.


func test_game_view_runs_a_scripted_take_off() -> void:
	var view := GameView.new()
	view.source = ScriptedSource.new(ScriptedInput.from_steps([{"t": 0.0, "move": [0, 0], "held": false}, {"t": 0.5, "move": [0, 1]}]))
	add_child_autofree(view)
	view.set_process(false)
	await wait_physics_frames(1)
	assert_not_null(view.sim, "match started on the standard ruleset")
	assert_eq(view.toy_views.size(), 1)
	# Feed frames by hand so the test does not depend on the machine's speed.
	for i in 90:
		view._process(1.0 / 30.0)
	assert_eq(view.sim.tick, 180, "30 fps frames, 60 Hz ticks")
	assert_true(view.player.jetpack_on, "took off")
	var drawn := view.toy_views[0].position
	assert_eq(drawn, view.player_view_position(), "the toy is drawn where the view says")


func test_view_draws_between_ticks() -> void:
	var view := GameView.new()
	view.source = ScriptedSource.new(ScriptedInput.from_steps([{"t": 0.0, "move": [1, 0]}]))
	add_child_autofree(view)
	view.set_process(false)
	await wait_physics_frames(1)
	for i in 60:
		view._process(1.0 / 60.0)
	view._process(SimClock.TICK * 0.5)
	var p := view.toy_views[0].position
	var a := view.player.prev_position
	var b := view.player.position
	assert_almost_eq(p.x, (a.x + b.x) * 0.5, 0.01, "halfway between the last two ticks")


func test_bad_ruleset_is_refused_in_the_game() -> void:
	var view := GameView.new()
	view.ruleset_dir = "res://data/rulesets/does_not_exist"
	add_child_autofree(view)
	await wait_physics_frames(1)
	assert_null(view.sim, "no match on a refused ruleset")
	assert_push_error("ruleset refused")


func test_blockout_map_is_a_valid_map() -> void:
	var m: GameMap = load("res://maps/bedroom_blockout/bedroom_blockout.tscn").instantiate()
	autofree(m)
	assert_gt(m.spawn_points().size(), 3, "spawn points")
	assert_gt(m.pickup_points().size(), 0, "pickup points")
	assert_eq(m.team_bases().size(), 2, "team bases")
	for p in m.pickup_points():
		assert_gt(p.items.size(), 0, "%s lists items" % p.name)
	for s in m.spawn_points():
		assert_true(m.bounds.has_point(s.position), "%s inside bounds" % s.name)
