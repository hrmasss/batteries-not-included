extends GutTest
## The app's loop from a player's side: first launch offers the lessons and never forces them
## (US-35.4), bootcamp offers the host's choices (US-19.1, US-36.1), and results go to the next
## match in one tap with the same players, teams and rules (US-20.3 to US-20.5).

const SETTINGS := "user://test_app.cfg"

var app: App


func before_each() -> void:
	DirAccess.remove_absolute(SETTINGS)
	app = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	app.settings_path = SETTINGS
	add_child(app)
	await wait_process_frames(2)


func after_each() -> void:
	app.queue_free()
	await wait_process_frames(2)
	DirAccess.remove_absolute(SETTINGS)


func _press(name: String) -> void:
	var b := app._screen.find_child(name, true, false) as BaseButton
	assert_not_null(b, "button %s" % name)
	if b != null:
		b.pressed.emit()
	await wait_process_frames(2)


func test_us35_4_first_launch_offers_lessons_never_forces() -> void:
	assert_true(app._screen is MainMenu)
	assert_not_null(app._screen.find_child("LessonOffer", true, false), "lessons offered on first launch")
	await _press("NotNow")
	await _press("Bootcamp")
	assert_true(app._screen is BootcampSetup, "bootcamp opens without lessons")
	app.show_menu()
	await wait_process_frames(2)
	assert_null(app._screen.find_child("LessonOffer", true, false), "offered once")


func test_us19_1_bootcamp_offers_the_host_choices() -> void:
	await _press("Bootcamp")
	for row in ["Mode", "Teams", "Map", "Bots", "Botskill", "Matchtime", "Killlimit", "Pickups"]:
		assert_true(app._screen.find_child(row, true, false) is ChoiceRow, "%s choice" % row)
	var bots := app._screen.find_child("Bots", true, false) as ChoiceRow
	assert_eq(bots.values.front(), 1, "US-36.1 from 1 bot")
	assert_eq(bots.values.back(), int(app.rules.players_max) - 1, "to 11 bots")


func test_us20_3_to_5_results_then_rematch_in_one_tap() -> void:
	var cfg := app.config.copy()
	cfg.mode = MatchConfig.Mode.TDM
	cfg.teams = 3
	cfg.bots = 5
	cfg.length = app.rules.match_length_min
	app.start_match(cfg)
	await wait_process_frames(2)
	var m := app._screen as MatchScreen
	assert_not_null(m, "a match runs")
	assert_eq(m.runner.bots.size(), 5)
	m.runner.run_to_end(roundi((cfg.length + 1.0) / SimClock.TICK))
	await wait_process_frames(2)
	var results := m.find_child("Results", true, false)
	assert_not_null(results, "results show")
	assert_not_null(results.find_child("ScoreTable", true, false), "with the full scoreboard")
	var seats := m.runner.scores.order.map(func(id: int) -> int: return m.runner.scores.row(id).team)
	var before := m.cfg.to_dict()
	await _press("Rematch")
	var again := app._screen as MatchScreen
	assert_true(again is MatchScreen and not is_instance_valid(m) or again != m, "one tap: a new match")
	var after := again.cfg.to_dict()
	before.erase("seed")
	after.erase("seed")
	assert_eq(after, before, "same setup")
	assert_eq(again.cfg.bots, cfg.bots, "same players")
	assert_eq(again.cfg.teams, cfg.teams, "same teams")
	assert_eq(again.runner.scores.order.map(func(id: int) -> int: return again.runner.scores.row(id).team), seats, "same seats on the same teams")
	assert_eq(again.cfg.length, cfg.length, "same rules")
	assert_false(again.runner.is_over(), "running")


func test_winner_lines() -> void:
	var cfg := MatchConfig.new()
	var r := MatchRules.Result.new()
	r.tie = true
	assert_eq(MatchScreen.winner_line(r, 1, cfg), "Tie game!")
	r.tie = false
	r.winner_id = 1
	assert_eq(MatchScreen.winner_line(r, 1, cfg), "You win!")
	cfg.mode = MatchConfig.Mode.TDM
	r.winner_team = 2
	assert_string_contains(MatchScreen.winner_line(r, 1, cfg), "Orange team wins!")
