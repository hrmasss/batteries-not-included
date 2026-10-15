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
var _clock: Label
var _scores_panel: ScoreTable
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
	_build_ui()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = Ui.theme()
	_layer.add_child(_ui)
	_clock = Ui.label("", Ui.FONT_BIG)
	_clock.name = "Clock"
	_clock.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_clock.position = Vector2(-40, 2)
	_clock.custom_minimum_size = Vector2(80, 0)
	_clock.add_theme_color_override("font_outline_color", Color.BLACK)
	_clock.add_theme_constant_override("outline_size", 4)
	_ui.add_child(_clock)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.position = Vector2(-150, 4)
	top.add_theme_constant_override("separation", 4)
	var scores_button := _small("Scores", _toggle_scores)
	scores_button.name = "ScoresButton"
	top.add_child(scores_button)
	top.add_child(_small("Menu", _toggle_pause))
	_ui.add_child(top)
	_scores_panel = ScoreTable.new(runner.scores, view.me.id())
	_scores_panel.visible = false
	_scores_panel.set_anchors_preset(Control.PRESET_CENTER)
	_ui.add_child(_scores_panel)


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
	_clock.text = Ui.clock(runner.time_left())
	var want := _hold_scores or Input.is_key_pressed(KEY_TAB)
	if _scores_panel.visible != want and _results == null:
		_scores_panel.visible = want
	if _scores_panel.visible:
		_scores_panel.refresh()
		_center(_scores_panel)


func _center(c: Control) -> void:
	c.reset_size()
	c.position = (_ui.size - c.size) * 0.5


func _toggle_scores() -> void:
	_hold_scores = not _hold_scores


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _results == null:
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if _results != null:
		return
	if _pause != null:
		_pause.queue_free()
		_pause = null
		view.process_mode = Node.PROCESS_MODE_INHERIT
		return
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
	_scores_panel.visible = false
	_clock.text = Ui.clock(0.0)
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
