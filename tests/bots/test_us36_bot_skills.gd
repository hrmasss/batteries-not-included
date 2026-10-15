extends CombatTest
## US-36.2, US-36.3, T-95 to T-98 on the flat test map: what a bot sees, how fast it turns,
## when it fires, and that it only ever hands the match an intent.

var runner: MatchRunner
var cfg: MatchConfig


func _setup(rects: Array = []) -> void:
	make(rects)
	cfg = MatchConfig.defaults(rules)
	cfg.length = rules.match_length_max
	runner = MatchRunner.new(sim, cfg)


## A bot at `x` on `level` and a still enemy at `enemy_x`, both unprotected.
func _duel(level: StringName, x: float, enemy_x: float, enemy_y: float = FLOOR) -> Array:
	var me := add(x)
	var them := add(enemy_x, Fighter.NO_TEAM, false, enemy_y)
	runner.add_human(them, "target")
	var b := runner.add_bot(me, "bot", level)
	intents.erase(me.id())
	return [b, them]


func _tick() -> void:
	runner.step(_copies())


func _levels() -> Array[StringName]:
	return rules.bots.order


func test_us36_3_three_levels_from_data() -> void:
	make()
	var order := _levels()
	assert_gte(order.size(), 3, "at least three skill levels")
	for k in range(1, order.size()):
		var lo := rules.bots.get_level(order[k - 1])
		var hi := rules.bots.get_level(order[k])
		assert_gte(hi.sight, lo.sight, "sight grows with skill")
		assert_lte(hi.reaction, lo.reaction, "reaction shrinks with skill")
		assert_gte(hi.turn_rate, lo.turn_rate, "aim turns faster with skill")
		assert_gte(hi.turn_gain, lo.turn_gain)
		assert_lte(hi.wait_max, lo.wait_max, "shorter waits between bursts")


func test_t95_t96_t97_easy_is_the_classic_floor() -> void:
	make()
	var easy := rules.bots.get_level(_levels()[0])
	assert_eq(easy.sight, 500.0, "T-95")
	# T-96: 1 + gap/20 degrees per step at 60 steps a second.
	assert_almost_eq(easy.turn_rate * TICK, 1.0, 0.0001)
	assert_almost_eq(easy.turn_gain * TICK, 1.0 / 20.0, 0.0001)
	assert_eq(easy.aim_dead_zone, 3.0)
	assert_eq([easy.first_wait, easy.first_burst, easy.wait_min, easy.wait_max, easy.burst_min, easy.burst_max], [3.0, 3.0, 0.0, 8.0, 0.0, 5.0], "T-97")


func test_t96_one_aim_step_turns_1_plus_gap_over_20() -> void:
	_setup()
	var d := _duel(_levels()[0], 1000, 1300)
	var b: Bot = d[0]
	b.aim_angle = -PI / 2.0
	b.target = d[1]
	b._wobble = 0.0
	var before := b.aim_gap()
	var i := InputIntent.new()
	b._aim(i, TICK)
	var turned := before - b.aim_gap()
	assert_almost_eq(turned, 1.0 + before / 20.0, 0.01, "classic step from a %.1f degree gap" % before)


func test_t96_aim_settles_faster_with_skill() -> void:
	var times: Array[float] = []
	for level in _levels():
		_setup()
		var d := _duel(level, 1000, 1300)
		var b: Bot = d[0]
		b.target = d[1]
		b.aim_angle = PI
		b._wobble = 0.0
		var t := 0.0
		while b.aim_gap() > b.skill.aim_dead_zone + 0.01 and t < 5.0:
			b._aim(InputIntent.new(), TICK)
			t += TICK
		times.append(t)
	for k in range(1, times.size()):
		assert_lt(times[k], times[k - 1], "level %d settles faster than level %d (%s)" % [k, k - 1, times])


func test_t95_sight_range_differs_by_level() -> void:
	make()
	var easy := rules.bots.get_level(_levels()[0])
	var hard := rules.bots.get_level(_levels()[-1])
	var gap := (easy.sight + hard.sight) / 2.0
	for level in [_levels()[0], _levels()[-1]]:
		_setup()
		var d := _duel(level, 1000, 1000 + gap)
		var b: Bot = d[0]
		for k in ticks(2.0):
			_tick()
		if level == _levels()[0]:
			assert_null(b.target, "easy does not see %d u away" % gap)
		else:
			assert_eq(b.target, d[1], "hard sees %d u away" % gap)


func test_t95_no_sight_through_walls() -> void:
	_setup([Rect2(1150, FLOOR - 400, 40, 400)])
	var d := _duel(_levels()[-1], 1000, 1300)
	var b: Bot = d[0]
	for k in ticks(2.0):
		_tick()
	assert_null(b.target, "the wall hides the enemy")


func test_t95_reaction_time_before_the_target_is_taken() -> void:
	for level in [_levels()[0], _levels()[-1]]:
		_setup()
		var d := _duel(level, 1000, 1200)
		var b: Bot = d[0]
		var t := 0.0
		while b.target == null and t < 5.0:
			_tick()
			t += TICK
		assert_almost_eq(t, b.skill.reaction, b.skill.look_interval + TICK * 2.0, "%s reacts after its reaction time" % level)


func test_t97_first_wait_then_first_burst() -> void:
	_setup()
	var d := _duel(_levels()[0], 1000, 1200)
	var b: Bot = d[0]
	var them: Fighter = d[1]
	var first_shot := -1.0
	var last_shot := -1.0
	var t := 0.0
	while t < b.skill.reaction + b.skill.first_wait + b.skill.first_burst + 1.0:
		them.toy.health = rules.max_health
		_tick()
		t += TICK
		for e in combat.events:
			if e.type == &"shot" and e.toy == b.id():
				if first_shot < 0.0:
					first_shot = t
				last_shot = t
	var expect_first := b.skill.reaction + b.skill.first_wait
	assert_almost_eq(first_shot, expect_first, b.skill.look_interval + w_interval(b) + TICK * 3.0, "first shot after reaction and the first wait")
	assert_almost_eq(last_shot - first_shot, b.skill.first_burst, w_interval(b) + TICK * 3.0, "fires for the first burst")


func w_interval(b: Bot) -> float:
	return b.fighter.main_weapon().def.interval


func test_us36_2_t98_bot_toy_is_a_player_toy() -> void:
	_setup()
	var d := _duel(_levels()[1], 1000, 1200)
	var b: Bot = d[0]
	var human: Fighter = d[1]
	assert_eq(b.fighter.toy.hit_bounds().size, human.toy.hit_bounds().size, "same hitbox")
	assert_eq(b.fighter.toy.health, human.toy.health, "same health")
	assert_eq(b.fighter.toy.battery_max, human.toy.battery_max, "same battery")
	assert_eq(b.fighter.weapons.map(func(w: WeaponItem) -> StringName: return w.id()), human.weapons.map(func(w: WeaponItem) -> StringName: return w.id()), "same spawn kit")
	# Every intent a bot makes is already inside what the match server accepts.
	var ok := true
	for k in ticks(5.0):
		var i := b.intent(TICK)
		ok = ok and i.move.is_finite() and i.aim.is_finite() and i.move.length() <= 1.0 + 1e-5 and i.aim.length() <= 1.0 + 1e-5 and i.buttons == i.sanitized().buttons
		runner.sim.step({b.id(): i})
	assert_true(ok, "every intent in range")


func test_t98_bots_never_write_match_state() -> void:
	# Bots read the match and return intents; nothing under src/sim/bots assigns to a toy, a
	# fighter, the combat or the sim.
	var bad := RegEx.create_from_string("(toy|fighter|combat|sim|target|other|f|t|it|w)\\.[a-z_]+(\\.[a-z_]+)*\\s*([+\\-*/]?=)(?!=)")
	for file in DirAccess.get_files_at("res://src/sim/bots"):
		# The skill table's reader builds rows; it runs at load, not in play.
		if not file.ends_with(".gd") or file == "bot_skills.gd":
			continue
		var text := FileAccess.get_file_as_string("res://src/sim/bots".path_join(file))
		for line in text.split("\n"):
			var code := line.substr(0, line.find("#")) if line.find("#") >= 0 else line
			var m := bad.search(code)
			if m != null and not code.strip_edges().begins_with("var "):
				fail_test("%s writes match state: %s" % [file, code.strip_edges()])
	pass_test("checked")
