class_name MatchScreen
extends Node
## A bootcamp match on this phone: the game view, the match server's runner with its bots,
## the clock, the scoreboard on demand (US-20.2), a pause menu, and the results with rematch
## in one tap (US-20.3 to US-20.5).

var app: App
var cfg: MatchConfig
var view: GameView
var runner: MatchRunner
var names: PackedStringArray = []

var _layer: CanvasLayer
var _ui: Control
var _scores_panel: ScoreTable
var _scores_box: VBoxContainer
var _pause: Control
var _results: Control
var _hold_scores: bool = false


func _init(owner_app: App, match_config: MatchConfig) -> void:
	app = owner_app
	cfg = match_config
	name = "MatchScreen"


func _ready() -> void:
	view = GameView.new()
	view.name = "GameView"
	view.ruleset = cfg.apply(app.rules)
	view.map_scene = load(cfg.map_path)
	view.player_team = cfg.team_of_seat(0)
	view.combat_seed = cfg.seed_value
	view.show_overlay = app.settings.tuning_overlay
	var autoplay: BotSource = null
	if app.autoplay:
		autoplay = BotSource.new()
		view.source = autoplay
	add_child(view)
	runner = MatchRunner.new(view.sim, cfg)
	runner.add_human(view.me, "You")
	names = BotNames.pick(cfg.bots, cfg.seed_value)
	for f in runner.spawn_bots(names):
		view.add_toy_view(f.toy)
	if autoplay != null:
		var skill := app.rules.bots.get_level(cfg.skill)
		autoplay.bot = Bot.new(view.me, skill, view.sim, runner.nav, cfg.seed_value)
	view.stepper = runner.step
	runner.ended.connect(_on_ended)
	# The HUD reads names and the clock from whoever runs the match.
	var hud_source := view.player_hud.source
	for id: int in runner.scores.rows:
		hud_source.names[id] = runner.scores.row(id).name
	hud_source.clock_running = false
	hud_source.clock = runner.time_left()
	_build_ui()
	print("bni: match started, %d bots, %s" % [cfg.bots, "team deathmatch" if cfg.is_teams() else "free-for-all"])


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = Ui.theme()
	_layer.add_child(_ui)
	# Tap the HUD's clock and scores for the full scoreboard (US-20.2).
	var clock_tap := Button.new()
	clock_tap.name = "ScoresButton"
	clock_tap.flat = true
	clock_tap.focus_mode = Control.FOCUS_NONE
	clock_tap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	clock_tap.position = Vector2(-46, 4)
	clock_tap.size = Vector2(92, 46)
	clock_tap.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	clock_tap.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	clock_tap.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	clock_tap.pressed.connect(_toggle_scores)
	_ui.add_child(clock_tap)
	_scores_panel = ScoreTable.new(runner.scores, view.me.id())
	_scores_box = VBoxContainer.new()
	_scores_box.name = "Scores"
	_scores_box.visible = false
	_scores_box.add_child(_scores_panel)
	_scores_box.add_child(Ui.row([_small("Close", _toggle_scores), _small("Menu", _toggle_pause)]))
	_ui.add_child(_scores_box)


func _small(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.name = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(68, 26)
	b.add_theme_font_size_override("font_size", Ui.FONT_SMALL)
	b.pressed.connect(on_press)
	return b


func _process(_delta: float) -> void:
	if runner == null:
		return
	view.player_hud.source.clock = runner.time_left()
	var want := (_hold_scores or Input.is_key_pressed(KEY_TAB)) and _results == null and _pause == null
	if _scores_box.visible != want:
		_scores_box.visible = want
	if _scores_box.visible:
		_scores_panel.refresh()
		_center(_scores_box)


func _center(c: Control) -> void:
	c.reset_size()
	c.position = (_ui.size - c.size) * 0.5


func _toggle_scores() -> void:
	_hold_scores = not _hold_scores


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _results == null:
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Android's back gesture pauses, as Escape does.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _results == null and _pause == null:
		_toggle_pause()


func _toggle_pause() -> void:
	if _results != null:
		return
	if _pause != null:
		_pause.queue_free()
		_pause = null
		view.process_mode = Node.PROCESS_MODE_INHERIT
		return
	_hold_scores = false
	view.process_mode = Node.PROCESS_MODE_DISABLED
	_pause = _panel([
		Ui.label("Paused", Ui.FONT_BIG, Ui.ACCENT),
		Ui.button("Resume", _toggle_pause, true, 180),
		Ui.button("Restart", app.rematch, false, 180),
		Ui.button("Quit to menu", app.show_menu, false, 180),
	])


func _panel(children: Array) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	for c: Control in children:
		col.add_child(c)
	return dim


## US-20.3: the winner, the full scoreboard and the best player; rematch in one tap (US-20.5).
func _on_ended(result: MatchRules.Result) -> void:
	print("bni: match over: %s" % winner_line(result, view.me.id(), cfg))
	_hold_scores = false
	view.player_hud.source.clock = 0.0
	var table := ScoreTable.new(runner.scores, view.me.id())
	var children: Array = [
		Ui.label("FINAL RESULTS", Ui.FONT_SMALL, Ui.TEXT_DIM),
		Ui.label(winner_line(result, view.me.id(), cfg), Ui.FONT_BIG, Ui.ACCENT),
	]
	if cfg.is_teams():
		var parts: PackedStringArray = []
		for t: int in result.team_scores:
			parts.append("%s %d" % [Ui.team_name(t), result.team_scores[t]])
		children.append(Ui.label("   ".join(parts), Ui.FONT))
	children.append(table)
	if result.best != null:
		children.append(Ui.label("Best player: %s, %d kills, best streak %d" % [result.best.name, result.best.kills, result.best.best_streak], Ui.FONT_SMALL, Ui.GOOD))
	var rematch := Ui.button("Rematch", app.rematch, true, 150)
	rematch.name = "Rematch"
	children.append(Ui.row([Ui.button("Main menu", app.show_menu, false, 110), Ui.button("Change setup", app.show_bootcamp, false, 120), rematch]))
	_results = _panel(children)
	_results.name = "Results"
	rematch.grab_focus.call_deferred()


## "You win!", "Sprocket wins!", "▲ Orange team wins!" or "Tie game!".
static func winner_line(result: MatchRules.Result, me_id: int, match_config: MatchConfig) -> String:
	if result.tie:
		return "Tie game!"
	if match_config.is_teams():
		return "%s team wins!" % Ui.team_name(result.winner_team)
	if result.winner_id == me_id:
		return "You win!"
	for r in result.rows:
		if r.id == result.winner_id:
			return "%s wins!" % r.name
	return "Match over"
