extends CombatTest
## US-17, US-18, US-19.2, US-20.1: match end, winners, scores, with scripted fighters on the
## flat test map. Every expected number is read from the ruleset or the config.

var runner: MatchRunner
var cfg: MatchConfig


func _match(mode: MatchConfig.Mode, length: float = 60.0, teams: int = 2) -> void:
	make()
	cfg = MatchConfig.defaults(rules)
	cfg.mode = mode
	cfg.teams = teams
	cfg.length = length
	runner = MatchRunner.new(sim, cfg)


func _seat(x: float, team: int, player_name: String) -> Fighter:
	var f := add(x, team)
	runner.add_human(f, player_name)
	return f


func _pop(victim: Fighter, by: Fighter) -> void:
	victim.protect_left = 0.0
	combat.hurt(victim, rules.max_health, by.id() if by != null else 0, &"pistol", CombatSim.Hurt.BULLET)


func _tick() -> void:
	runner.step(_copies())


func test_us17_3_us18_match_ends_on_time() -> void:
	_match(MatchConfig.Mode.FFA, 3.0)
	_seat(300, Fighter.NO_TEAM, "a")
	_seat(900, Fighter.NO_TEAM, "b")
	var ticks := 0
	while not runner.is_over() and ticks < ticks(10.0):
		_tick()
		ticks += 1
	assert_true(runner.is_over(), "over")
	assert_eq(runner.rules.result.reason, MatchRules.End.TIME)
	assert_almost_eq(runner.rules.result.time, cfg.length, TICK, "at the time limit")
	var at := sim.tick
	_tick()
	assert_eq(sim.tick, at, "no ticks after the end")


func test_t72_default_length_is_390() -> void:
	make()
	assert_eq(MatchConfig.defaults(rules).length, rules.match_length)
	assert_eq(rules.match_length, 390.0, "04_tuning T-72 start value")
	assert_false(MatchConfig.defaults(rules).kill_limit_on, "T-73 off by default")


func test_us17_2_kill_adds_to_kills_and_team_score() -> void:
	_match(MatchConfig.Mode.TDM)
	var a := _seat(300, 1, "a")
	var b := _seat(900, 2, "b")
	_pop(b, a)
	_tick()
	assert_eq(runner.scores.row(a.id()).kills, 1)
	assert_eq(runner.scores.team_score(1), 1)
	assert_eq(runner.scores.team_score(2), 0)
	assert_eq(runner.scores.row(b.id()).deaths, 1)


func test_us17_4_kill_limit_ends_team_match() -> void:
	_match(MatchConfig.Mode.TDM)
	cfg.kill_limit_on = true
	cfg.kill_limit = 2
	var a := _seat(300, 1, "a")
	var b := _seat(900, 2, "b")
	_pop(b, a)
	_tick()
	assert_false(runner.is_over(), "one kill is short of the limit")
	run(rules.respawn_wait + TICK * 2)
	_pop(b, a)
	_tick()
	assert_true(runner.is_over(), "limit reached")
	assert_eq(runner.rules.result.reason, MatchRules.End.KILL_LIMIT)
	assert_eq(runner.rules.result.winner_team, 1)


func test_us17_4_kill_limit_off_by_default_runs_on() -> void:
	_match(MatchConfig.Mode.TDM)
	var a := _seat(300, 1, "a")
	var b := _seat(900, 2, "b")
	for k in int(rules.kill_limit) + 1:
		b.respawn_left = 0.0
		_tick()
		_pop(b, a)
		_tick()
	assert_eq(runner.scores.row(a.id()).kills, int(rules.kill_limit) + 1, "past the limit's value")
	assert_false(runner.is_over(), "no kill limit unless the host turns it on")


func test_us18_4_kill_limit_ends_ffa() -> void:
	_match(MatchConfig.Mode.FFA)
	cfg.kill_limit_on = true
	cfg.kill_limit = 1
	var a := _seat(300, Fighter.NO_TEAM, "a")
	var b := _seat(900, Fighter.NO_TEAM, "b")
	_seat(1500, Fighter.NO_TEAM, "c")
	_pop(b, a)
	_tick()
	assert_true(runner.is_over())
	assert_eq(runner.rules.result.reason, MatchRules.End.KILL_LIMIT)
	assert_eq(runner.rules.result.winner_id, a.id())


func test_us17_5_names_top_team_or_tie() -> void:
	_match(MatchConfig.Mode.TDM, 2.0)
	var a := _seat(300, 1, "a")
	var b := _seat(900, 2, "b")
	_pop(b, a)
	runner.run_to_end(ticks(5.0), _copies())
	assert_false(runner.rules.result.tie)
	assert_eq(runner.rules.result.winner_team, 1)
	_match(MatchConfig.Mode.TDM, 2.0)
	a = _seat(300, 1, "a")
	b = _seat(900, 2, "b")
	_pop(b, a)
	_pop(a, b)
	runner.run_to_end(ticks(5.0), _copies())
	assert_true(runner.rules.result.tie, "1 to 1 is a tie")
	assert_eq(runner.rules.result.winner_team, 0)


func test_us17_1_four_teams() -> void:
	_match(MatchConfig.Mode.TDM, 2.0, 4)
	var fs: Array[Fighter] = []
	for k in 8:
		fs.append(_seat(200 + k * 150, cfg.team_of_seat(k), "p%d" % k))
	assert_eq(runner.scores.teams(), [1, 2, 3, 4] as Array[int])
	_pop(fs[1], fs[2])
	runner.run_to_end(ticks(5.0), _copies())
	assert_eq(runner.rules.result.winner_team, cfg.team_of_seat(2))
	assert_eq(runner.rules.result.team_scores.size(), 4)


func test_us18_2_names_top_player_or_tie() -> void:
	_match(MatchConfig.Mode.FFA, 2.0)
	var a := _seat(300, Fighter.NO_TEAM, "a")
	var b := _seat(900, Fighter.NO_TEAM, "b")
	var c := _seat(1500, Fighter.NO_TEAM, "c")
	_pop(b, c)
	runner.run_to_end(ticks(5.0), _copies())
	assert_eq(runner.rules.result.winner_id, c.id())
	assert_eq(runner.rules.result.best.id, c.id(), "US-20.3 best player")
	_match(MatchConfig.Mode.FFA, 2.0)
	a = _seat(300, Fighter.NO_TEAM, "a")
	b = _seat(900, Fighter.NO_TEAM, "b")
	runner.run_to_end(ticks(5.0), _copies())
	assert_true(runner.rules.result.tie, "0 to 0 is a tie")


func test_us18_1_ffa_everyone_is_an_enemy() -> void:
	_match(MatchConfig.Mode.FFA)
	var a := _seat(300, cfg.team_of_seat(0), "a")
	var b := _seat(340, cfg.team_of_seat(1), "b")
	assert_eq(a.team, Fighter.NO_TEAM)
	assert_false(a.is_teammate(b))
	set_intent(a, AIM_RIGHT, true)
	run(0.5)
	assert_lt(b.toy.health, rules.max_health, "a's bullets hit b")


func test_us18_3_ends_when_one_player_left() -> void:
	_match(MatchConfig.Mode.FFA)
	var a := _seat(300, Fighter.NO_TEAM, "a")
	var b := _seat(900, Fighter.NO_TEAM, "b")
	_tick()
	assert_false(runner.is_over())
	runner.leave(b.id())
	_tick()
	assert_true(runner.is_over())
	assert_eq(runner.rules.result.reason, MatchRules.End.LAST_PLAYER)
	assert_eq(runner.rules.result.winner_id, a.id())


func test_us17_6_ends_when_one_team_left() -> void:
	_match(MatchConfig.Mode.TDM)
	_seat(300, 1, "a")
	_seat(500, 1, "a2")
	var b := _seat(900, 2, "b")
	_tick()
	assert_false(runner.is_over())
	runner.leave(b.id())
	_tick()
	assert_true(runner.is_over())
	assert_eq(runner.rules.result.reason, MatchRules.End.LAST_TEAM)


func test_us20_1_scores_kept_per_player() -> void:
	_match(MatchConfig.Mode.TDM, 60.0)
	var a := _seat(300, 1, "a")
	var mate := _seat(340, 1, "mate")
	var b := _seat(900, 2, "b")
	var c := _seat(1500, 2, "c")
	# Damage to an enemy counts; to a teammate or yourself it does not.
	combat.hurt(b, 30.0, a.id(), &"pistol", CombatSim.Hurt.BULLET)
	combat.hurt(mate, 20.0, a.id(), &"frag", CombatSim.Hurt.BLAST)
	combat.hurt(a, 10.0, a.id(), &"frag", CombatSim.Hurt.BLAST)
	assert_eq(runner.scores.row(a.id()).damage, 30.0, "damage to enemies only")
	# Two kills in a row: a streak of 2.
	_pop(b, a)
	_pop(c, a)
	var row := runner.scores.row(a.id())
	assert_eq(row.kills, 2)
	assert_eq(row.streak, 2)
	assert_eq(row.best_streak, 2)
	# A team kill: a suicide and a team kill for the killer, no kill.
	_pop(mate, a)
	assert_eq(row.kills, 2)
	assert_eq(row.team_kills, 1)
	assert_eq(row.suicides, 1)
	# Own pop: a suicide and a death; the streak ends, the best stays.
	_pop(a, a)
	assert_eq(row.suicides, 2)
	assert_eq(row.deaths, 1)
	assert_eq(row.streak, 0)
	assert_eq(row.best_streak, 2)
	# The scoreboard agrees with the match server's own counts.
	for f in [a, mate, b, c]:
		var r := runner.scores.row((f as Fighter).id())
		assert_eq(r.kills, (f as Fighter).kills, "kills %s" % r.name)
		assert_eq(r.deaths, (f as Fighter).deaths, "deaths %s" % r.name)
		assert_eq(r.suicides, (f as Fighter).suicides, "suicides %s" % r.name)
		assert_eq(r.team_kills, (f as Fighter).team_kills, "team kills %s" % r.name)


func test_us19_2_config_applies_batteries_included_and_pickups() -> void:
	make()
	cfg = MatchConfig.defaults(rules)
	cfg.batteries_included = true
	cfg.pickup_interval = 0.0
	var r := cfg.apply(rules)
	assert_true(r.batteries_included)
	assert_eq(r.pickup_interval, 0.0)
	assert_false(rules.batteries_included, "the ruleset itself is untouched")
	assert_eq(r.walk_speed, rules.walk_speed, "nothing else changes")


func test_us36_1_config_clamps_bots_1_to_11() -> void:
	make()
	cfg = MatchConfig.defaults(rules)
	cfg.bots = 0
	cfg.clamp_to(rules)
	assert_eq(cfg.bots, 1)
	cfg.bots = 40
	cfg.clamp_to(rules)
	assert_eq(cfg.bots, int(rules.players_max) - 1)
	assert_eq(cfg.bots, 11, "T-75: 12 players, so 11 bots and you")
	cfg.teams = 9
	cfg.clamp_to(rules)
	assert_eq(cfg.teams, int(rules.teams_max))
