extends Node
## Plays a scripted run in the game view and saves screenshots at set times. Driven by
## tools/shot.sh; reads its options after `--`:
##   --run <path to run JSON>   --out <directory for PNGs>
##
## Run JSON:
##   {
##     "duration": 12.0,               seconds of sim time, then quit
##     "overlay": true, "hitboxes": false,
##     "map": "res://maps/...tscn",    optional
##     "ruleset": "res://data/...",    optional
##     "spawn": 0,                     optional spawn point index
##     "team": 0, "seed": 0,           optional player team and match seed
##     "dummies": [{"at": [x, y], "team": 1, "protect": false, "aim": [-1, 0], "fire": true}],
##                                     optional targets; they stand still and may hold fire.
##                                     With "steps" (ScriptedInput steps) they move too; with
##                                     "aim_at_player": true their aim tracks the player
##     "arm": ["assault_rifle"],       optional: the player's weapons, replacing the spawn kit
##                                     (dummies take "arm" too)
##     "aim_at_enemy": true,           optional: the player's aim tracks the nearest enemy
##     "perf": true,                   optional: log frame time and draw calls, write perf.json
##     "items": [{"item": "smg", "at": [x, y]}],   optional items put on the floor
##     "steps": [ScriptedInput steps],
##     "shots": [{"t": 1.0, "name": "standing", "hitboxes": true},
##               {"when": "battery_empty", "delay": 0.3, "name": "falling"},
##               {"when": "pop", "who": "other", "delay": 0.1, "name": "popped"}]
##   }
## "when" is "battery_empty" or any combat event type (shot, hit, blocked, blast, pop, spawn,
## pickup, throw...); "who" narrows it to events about the player ("me") or anyone else ("other").

var _view: GameView
## Moving dummies: [fighter, ScriptedInput, aim at player].
var _movers: Array = []
var _perf: bool = false
var _perf_rows: Array = []
var _shots: Array = []
## Shots set off by something happening, then a delay: "battery_empty".
var _events: Array = []
var _out: String = ""
var _duration: float = 10.0
var _taking: bool = false
## Seconds past the run's duration to wait for shots set off by events, then give up.
const LATE := 5.0


func _ready() -> void:
	var args := _args()
	var run_path: String = args.get("run", "")
	_out = args.get("out", "user://shots")
	var run: Variant = JSON.parse_string(FileAccess.get_file_as_string(run_path))
	if typeof(run) != TYPE_DICTIONARY:
		push_error("shot: cannot read run %s" % run_path)
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_duration = float(run.get("duration", 10.0))
	_perf = bool(run.get("perf", false))
	for shot: Dictionary in run.get("shots", []):
		if shot.has("when"):
			_events.append(shot)
		else:
			_shots.append(shot)
	_shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	_view = GameView.new()
	_view.show_overlay = bool(run.get("overlay", true))
	_view.show_hitboxes = bool(run.get("hitboxes", false))
	if run.has("map"):
		_view.map_scene = load(run.map)
	if run.has("ruleset"):
		_view.ruleset_dir = run.ruleset
	_view.spawn_index = int(run.get("spawn", 0))
	_view.player_team = int(run.get("team", 0))
	_view.combat_seed = int(run.get("seed", 0))
	var aiming := ShotAimingSource.new(ScriptedInput.from_steps(run.get("steps", [])))
	aiming.track = bool(run.get("aim_at_enemy", false))
	_view.source = aiming
	add_child(_view)
	if _view.combat != null:
		_arm(_view.me, run.get("arm", []))
		for d: Dictionary in run.get("dummies", []):
			var at: Variant = Vector2(float(d.at[0]), float(d.at[1])) if d.has("at") else null
			var f := _view.add_dummy(int(d.get("team", 1)), at, bool(d.get("protect", false)))
			_arm(f, d.get("arm", []))
			if d.has("steps"):
				_movers.append([f, ScriptedInput.from_steps(d.steps), bool(d.get("aim_at_player", false))])
			elif d.has("aim") or d.has("fire"):
				var aim: Array = d.get("aim", [1, 0])
				var i := InputIntent.make(Vector2.ZERO, false, Vector2(float(aim[0]), float(aim[1])))
				i.fire = bool(d.get("fire", false))
				_view.extra_intents[f.id()] = i
		for it: Dictionary in run.get("items", []):
			_view.combat.place_item(StringName(it.item), Vector2(float(it.at[0]), float(it.at[1])))
		_view.combat.event.connect(_on_combat_event)


func _on_combat_event(e: Dictionary) -> void:
	var now := _view.sim.tick * SimClock.TICK
	var mine: bool = e.get("toy", 0) == _view.me.id()
	for shot: Dictionary in _events.duplicate():
		if shot.when != String(e.type):
			continue
		var who: String = shot.get("who", "")
		if (who == "me" and not mine) or (who == "other" and mine):
			continue
		_events.erase(shot)
		shot.t = now + float(shot.get("delay", 0.0))
		_shots.append(shot)
	_shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))


func _arm(f: Fighter, ids: Array) -> void:
	if ids.is_empty():
		return
	f.weapons.clear()
	for id: String in ids:
		f.weapons.append(WeaponItem.fresh(_view.sim.rules.weapons.get_def(StringName(id))))
	f.held = 0


func _process(delta: float) -> void:
	if _view == null or _view.sim == null or _taking:
		return
	var now := _view.sim.tick * SimClock.TICK
	if _perf and _view.sim.tick > 30:
		_perf_rows.append([
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_frame_setup_time_cpu(),
			delta * 1000.0,
		])
	for m: Array in _movers:
		var f: Fighter = m[0]
		var i: InputIntent = (m[1] as ScriptedInput).intent_at(now).copy()
		if m[2]:
			i.aim = ShotAimingSource.aim_from_to(f.toy.position, _view.player.position, i.aim)
		_view.extra_intents[f.id()] = i
	for e: Dictionary in _events.duplicate():
		if e.when == "battery_empty" and _view.player.battery <= 0.0:
			_events.erase(e)
			e.t = now + float(e.get("delay", 0.0))
			_shots.append(e)
			_shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	if not _shots.is_empty() and now >= float(_shots[0].t):
		_take(_shots.pop_front())
	elif _shots.is_empty() and _events.is_empty() and now >= _duration:
		_write_perf()
		get_tree().quit(0)
	elif now >= _duration + LATE:
		push_error("shot: never happened: %s" % ", ".join(_events.map(func(e: Dictionary) -> String: return e.name)))
		get_tree().quit(3)


func _write_perf() -> void:
	if not _perf or _perf_rows.is_empty():
		return
	var names := ["process_ms", "draw_calls", "objects", "primitives", "render_setup_cpu_ms", "frame_ms"]
	var out := {"frames": _perf_rows.size(), "toys": _view.sim.toys.size(), "particles": FxField.of(_view).particles.size()}
	for k in names.size():
		var col: Array = _perf_rows.map(func(r: Array) -> float: return float(r[k]))
		col.sort()
		var total := 0.0
		for v: float in col:
			total += v
		out[names[k]] = {"mean": snappedf(total / col.size(), 0.01), "p95": snappedf(col[int(col.size() * 0.95)], 0.01), "max": snappedf(col[-1], 0.01)}
	var f := FileAccess.open(_out.path_join("perf.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	print("perf ", JSON.stringify(out))


func _take(shot: Dictionary) -> void:
	_taking = true
	var keep := _view.show_hitboxes
	if shot.has("hitboxes"):
		_view.show_hitboxes = bool(shot.hitboxes)
	await RenderingServer.frame_post_draw
	var path := _out.path_join("%s.png" % shot.name)
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("shot %s at %.2f s: %s" % [path, _view.sim.tick * SimClock.TICK, error_string(err)])
	_view.show_hitboxes = keep
	_taking = false


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size():
			out[a[i].substr(2)] = a[i + 1]
			i += 2
		else:
			i += 1
	return out
