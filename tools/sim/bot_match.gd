extends SceneTree
## Runs one bootcamp match headless and prints the scoreboard and how the bots moved.
## godot --headless --path . -s tools/sim/bot_match.gd -- [bots] [seconds] [mode ffa|tdm] [skill] [seed] [map: bedroom|blockout|res path]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var loaded := RulesetLoader.load_standard()
	if not loaded.ok():
		push_error(str(loaded.errors))
		quit(1)
		return
	var cfg := MatchConfig.defaults(loaded.ruleset)
	cfg.bots = int(args[0]) if args.size() > 0 else 7
	cfg.length = float(args[1]) if args.size() > 1 else 120.0
	cfg.mode = MatchConfig.Mode.TDM if args.size() > 2 and args[2] == "tdm" else MatchConfig.Mode.FFA
	if args.size() > 3:
		cfg.skill = StringName(args[3])
	cfg.seed_value = int(args[4]) if args.size() > 4 else 1
	if args.size() > 5:
		cfg.map_path = {"bedroom": MatchConfig.DEFAULT_MAP, "blockout": MatchConfig.BLOCKOUT_MAP}.get(args[5], args[5])
	print("map %s" % cfg.map_path)
	var rules := cfg.apply(loaded.ruleset)
	var sim := MatchSim.new()
	sim.setup(rules, (load(cfg.map_path) as PackedScene).instantiate())
	root.add_child(sim)
	await process_frame
	sim.start_combat(cfg.seed_value)
	var runner := MatchRunner.new(sim, cfg)
	var t0 := Time.get_ticks_msec()
	runner.spawn_bots()
	print("nav built and bots spawned in %d ms" % (Time.get_ticks_msec() - t0))
	var cells := {}
	var still := {}
	var longest := {}
	var anchor := {}
	t0 = Time.get_ticks_msec()
	var ticks := 0
	while not runner.is_over():
		runner.step()
		ticks += 1
		if ticks % 30 == 0:
			for b in runner.bots:
				var p := b.fighter.toy.position
				cells[b.id()] = cells.get(b.id(), {})
				cells[b.id()][Vector2i(p / 64.0)] = true
				if not b.fighter.alive:
					anchor[b.id()] = null
					continue
				var a: Variant = anchor.get(b.id(), null)
				if a == null or p.distance_to(a) > 50.0:
					anchor[b.id()] = p
					still[b.id()] = 0.0
				else:
					still[b.id()] = still.get(b.id(), 0.0) + 0.5
					longest[b.id()] = maxf(longest.get(b.id(), 0.0), still[b.id()])
	var ms := Time.get_ticks_msec() - t0
	print("%d ticks in %d ms (%.3f ms/tick)" % [ticks, ms, float(ms) / ticks])
	var r := runner.rules.result
	print("ended: %s tie=%s winner=%d team=%d best=%s" % [MatchRules.End.keys()[r.reason], r.tie, r.winner_id, r.winner_team, r.best.name])
	for row in r.rows:
		var b: Bot = null
		for x in runner.bots:
			if x.id() == row.id:
				b = x
		print("%-8s team %d  K %2d D %2d S %d TK %d dmg %5.0f best streak %d | cells %3d stuck %d longest still %.1f s" % [row.name, row.team, row.kills, row.deaths, row.suicides, row.team_kills, row.damage, row.best_streak, cells.get(row.id, {}).size(), b.stuck_events, longest.get(row.id, 0.0)])
	quit(0)
