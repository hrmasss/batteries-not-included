extends GutTest
## US-36.1, US-36.4 as far as a headless match can show them: bots on the real map finish a
## match, keep moving, fly, take pickups and throw frags, and the scores add up.

const MAP := "res://maps/bedroom_blockout/bedroom_blockout.tscn"
## A bot counts as stuck if it stays inside this many u for longer than STILL_LIMIT s while alive.
const STILL_RADIUS := 50.0
const STILL_LIMIT := 25.0
const SAMPLE := 30

var sim: MatchSim


## The map these checks run on; test_bots_on_bedroom.gd runs them all again on the art bedroom.
func map_path() -> String:
	return MAP


func _run(mode: MatchConfig.Mode, bots: int, length: float, level: StringName = &"", seed_value: int = 1) -> Dictionary:
	if sim != null and is_instance_valid(sim) and sim.get_parent() != null:
		sim.get_parent().remove_child(sim)
	var loaded := RulesetLoader.load_standard()
	var cfg := MatchConfig.defaults(loaded.ruleset)
	cfg.mode = mode
	cfg.bots = bots
	cfg.length = length
	cfg.seed_value = seed_value
	if level != &"":
		cfg.skill = level
	sim = MatchSim.new()
	sim.setup(cfg.apply(loaded.ruleset), (load(map_path()) as PackedScene).instantiate())
	add_child(sim)
	autofree(sim)
	sim.start_combat(seed_value)
	var runner := MatchRunner.new(sim, cfg)
	runner.spawn_bots()
	var stats := {"runner": runner, "throws": 0, "pickups": 0, "still": 0.0, "cells": {}}
	var bot_ids := {}
	for b in runner.bots:
		bot_ids[b.id()] = true
	sim.combat.event.connect(func(e: Dictionary) -> void:
		if e.type == &"throw" and bot_ids.has(e.toy):
			stats.throws += 1
		elif e.type == &"pickup" and bot_ids.has(e.toy):
			stats.pickups += 1)
	var anchor := {}
	var still := {}
	var ticks := 0
	while not runner.is_over() and ticks < int((length + 5.0) / SimClock.TICK):
		runner.step()
		ticks += 1
		if ticks % SAMPLE != 0:
			continue
		for b in runner.bots:
			var p := b.fighter.toy.position
			stats.cells[Vector2i(p / STILL_RADIUS)] = true
			if not b.fighter.alive:
				anchor.erase(b.id())
				continue
			if not anchor.has(b.id()) or p.distance_to(anchor[b.id()]) > STILL_RADIUS:
				anchor[b.id()] = p
				still[b.id()] = 0.0
			else:
				still[b.id()] += SAMPLE * SimClock.TICK
				stats.still = maxf(stats.still, still[b.id()])
	return stats


func _check_scores(runner: MatchRunner) -> void:
	var kills := 0
	var deaths := 0
	var suicides := 0
	for b in runner.bots:
		var row := runner.scores.row(b.id())
		var f := b.fighter
		assert_eq([row.kills, row.deaths, row.suicides, row.team_kills], [f.kills, f.deaths, f.suicides, f.team_kills], "scoreboard agrees with the match server for %s" % row.name)
		kills += row.kills
		deaths += row.deaths
		suicides += row.suicides
	assert_eq(deaths, kills + suicides, "every pop is a kill or a suicide (team kills count as suicides)")
	if runner.config.is_teams():
		var team_total := 0
		for t in runner.scores.teams():
			team_total += runner.scores.team_score(t)
		assert_eq(team_total, kills, "team scores add up to the kills")


func test_us36_1_ffa_eleven_bots_finish_a_match() -> void:
	var s := _run(MatchConfig.Mode.FFA, 11, 120.0)
	var runner: MatchRunner = s.runner
	assert_true(runner.is_over(), "the match ends")
	assert_eq(runner.rules.result.reason, MatchRules.End.TIME)
	assert_eq(runner.bots.size(), 11)
	_check_scores(runner)
	var kills := 0
	var flew := 0
	for b in runner.bots:
		kills += b.fighter.kills
		if b.fighter.toy.flight_time > 0.0:
			flew += 1
	assert_gt(kills, 0, "bots pop each other")
	assert_eq(flew, 11, "every bot flies")
	assert_lt(s.still, STILL_LIMIT, "no bot stays put longer than %d s" % STILL_LIMIT)
	assert_gt(s.throws, 0, "bots throw frags")
	assert_gt(s.pickups, 0, "bots take pickups")
	gut.p("still %.1f s, throws %d, pickups %d, kills %d, cells %d" % [s.still, s.throws, s.pickups, kills, s.cells.size()])


func test_us36_1_tdm_bots_finish_a_match() -> void:
	for teams in [2, 4]:
		var loaded := RulesetLoader.load_standard()
		var s := _run(MatchConfig.Mode.TDM, 11, 90.0, &"", teams)
		var runner: MatchRunner = s.runner
		assert_true(runner.is_over())
		_check_scores(runner)
		assert_lt(s.still, STILL_LIMIT)


func test_us36_1_four_teams_of_bots() -> void:
	var loaded := RulesetLoader.load_standard()
	var cfg := MatchConfig.defaults(loaded.ruleset)
	cfg.mode = MatchConfig.Mode.TDM
	cfg.teams = 4
	var seen := {}
	for seat in 12:
		seen[cfg.team_of_seat(seat)] = int(seen.get(cfg.team_of_seat(seat), 0)) + 1
	assert_eq(seen.keys().size(), 4)
	for t: int in seen:
		assert_eq(seen[t], 3, "even sides")


func test_us36_1_one_bot_each_level() -> void:
	for level: StringName in RulesetLoader.load_standard().ruleset.bots.order:
		var s := _run(MatchConfig.Mode.FFA, 1, 60.0, level)
		var runner: MatchRunner = s.runner
		assert_true(runner.is_over(), "%s: one bot alone finishes" % level)
		assert_lt(s.still, STILL_LIMIT, "%s keeps moving" % level)


func test_nf12_bot_match_replays_exactly() -> void:
	var a := _run(MatchConfig.Mode.FFA, 5, 20.0, &"", 9)
	var pa: Array = (a.runner as MatchRunner).bots.map(func(b: Bot) -> Vector2: return b.fighter.toy.position)
	var b := _run(MatchConfig.Mode.FFA, 5, 20.0, &"", 9)
	var pb: Array = (b.runner as MatchRunner).bots.map(func(x: Bot) -> Vector2: return x.fighter.toy.position)
	assert_eq(pa, pb, "same seed, same match")
