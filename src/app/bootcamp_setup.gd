class_name BootcampSetup
extends Control
## Bootcamp: play against 1 to 11 bots (US-36.1). Mode, teams, map, bots, skill, match time,
## kill limit, pickups and Batteries Included (US-19.1, US-19.2), each from the ruleset's
## allowed choices. The last setup is kept for next time.

var app: App
var cfg: MatchConfig
var _teams_row: ChoiceRow
var _limit_row: ChoiceRow


func _init(owner_app: App) -> void:
	app = owner_app
	name = "BootcampSetup"
	cfg = owner_app.config.copy()


func _ready() -> void:
	var rules := app.rules
	var page := Ui.screen(self)
	page.add_child(Ui.label("BOOTCAMP", Ui.FONT_BIG, Ui.ACCENT))
	page.add_child(Ui.label("You against 1 to 11 bots, offline.", Ui.FONT_SMALL, Ui.TEXT_DIM))
	var cols := HBoxContainer.new()
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_theme_constant_override("separation", 12)
	page.add_child(cols)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	cols.add_child(col)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)

	_add(col, "Mode", [MatchConfig.Mode.FFA, MatchConfig.Mode.TDM], ["Free-for-all", "Team deathmatch"], cfg.mode, func(v: Variant) -> void:
		cfg.mode = v
		_teams_row.visible = cfg.is_teams())
	var team_counts: Array = range(int(rules.teams_min), int(rules.teams_max) + 1)
	_teams_row = _add(col, "Teams", team_counts, PackedStringArray(team_counts.map(func(n: int) -> String: return "%d teams" % n)), cfg.teams, func(v: Variant) -> void: cfg.teams = v)
	_teams_row.visible = cfg.is_teams()
	var map_paths: Array = app.maps.map(func(m: Dictionary) -> String: return m.path)
	var map_names := PackedStringArray(app.maps.map(func(m: Dictionary) -> String: return m.name))
	if not map_paths.is_empty():
		_add(col, "Map", map_paths, map_names, cfg.map_path, func(v: Variant) -> void: cfg.map_path = v)
	var bot_counts: Array = range(1, int(rules.players_max))
	_add(col, "Bots", bot_counts, PackedStringArray(bot_counts.map(func(n: int) -> String: return "%d bot%s" % [n, "" if n == 1 else "s"])), cfg.bots, func(v: Variant) -> void: cfg.bots = v)
	var levels: Array = rules.bots.order.duplicate()
	_add(col, "Bot skill", levels, PackedStringArray(levels.map(func(s: StringName) -> String: return String(s).capitalize())), cfg.skill, func(v: Variant) -> void: cfg.skill = v)
	var lengths: Array = []
	var t := rules.match_length_min
	while t <= rules.match_length_max + CombatSim.TIME_EPSILON:
		lengths.append(t)
		t += rules.match_length_step
	if not lengths.has(cfg.length):
		lengths.append(cfg.length)
		lengths.sort()
	_add(right, "Match time", lengths, PackedStringArray(lengths.map(func(s: float) -> String: return Ui.clock(s))), cfg.length, func(v: Variant) -> void: cfg.length = v)
	var limits: Array = [0]
	for k in range(5, 55, 5):
		limits.append(k)
	if not limits.has(int(rules.kill_limit)):
		limits.append(int(rules.kill_limit))
		limits.sort()
	var current_limit: int = cfg.kill_limit if cfg.kill_limit_on else 0
	_limit_row = _add(right, "Kill limit", limits, PackedStringArray(limits.map(func(n: int) -> String: return "Off" if n == 0 else "%d kills" % n)), current_limit, func(v: Variant) -> void:
		cfg.kill_limit_on = int(v) > 0
		if int(v) > 0:
			cfg.kill_limit = v)
	# T-76: off, 30, 60, 90, 120 s.
	var intervals: Array = [0.0, 30.0, 60.0, 90.0, 120.0]
	if not intervals.has(cfg.pickup_interval):
		intervals.append(cfg.pickup_interval)
		intervals.sort()
	_add(right, "Pickups", intervals, PackedStringArray(intervals.map(func(s: float) -> String: return "Off" if s <= 0.0 else "Every %d s" % int(s))), cfg.pickup_interval, func(v: Variant) -> void: cfg.pickup_interval = v)
	_add(right, "Batteries Incl.", [false, true], ["Off", "On"], cfg.batteries_included, func(v: Variant) -> void: cfg.batteries_included = v)

	var start := Ui.button("Start", _start, true, 180)
	start.name = "Start"
	right.add_child(Ui.label("Batteries Included: endless battery and ammo.", Ui.FONT_SMALL, Ui.TEXT_DIM))
	page.add_child(Ui.row([Ui.button("Back", app.show_menu, false, 100), start]))
	start.grab_focus.call_deferred()


func _add(col: VBoxContainer, title: String, values: Array, texts: PackedStringArray, current: Variant, on_change: Callable) -> ChoiceRow:
	var r := ChoiceRow.new(title, values, texts, current)
	r.changed.connect(on_change)
	col.add_child(r)
	return r


func _start() -> void:
	cfg.clamp_to(app.rules)
	app.start_match(cfg)
