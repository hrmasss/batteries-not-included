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
##                                     optional targets; they stand still and may hold fire
##     "items": [{"item": "smg", "at": [x, y]}],   optional items put on the floor
##     "steps": [ScriptedInput steps],
##     "shots": [{"t": 1.0, "name": "standing", "hitboxes": true},
##               {"when": "battery_empty", "delay": 0.3, "name": "falling"},
##               {"when": "pop", "who": "other", "delay": 0.1, "name": "popped"}]
##   }
## "when" is "battery_empty" or any combat event type (shot, hit, blocked, blast, pop, spawn,
## pickup, throw...); "who" narrows it to events about the player ("me") or anyone else ("other").

var _view: GameView
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
	_view.source = ScriptedSource.new(ScriptedInput.from_steps(run.get("steps", [])))
	add_child(_view)
	if _view.combat != null:
		for d: Dictionary in run.get("dummies", []):
			var at: Variant = Vector2(float(d.at[0]), float(d.at[1])) if d.has("at") else null
			var f := _view.add_dummy(int(d.get("team", 1)), at, bool(d.get("protect", false)))
			if d.has("aim") or d.has("fire"):
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


func _process(_delta: float) -> void:
	if _view == null or _view.sim == null or _taking:
		return
	var now := _view.sim.tick * SimClock.TICK
	for e: Dictionary in _events.duplicate():
		if e.when == "battery_empty" and _view.player.battery <= 0.0:
			_events.erase(e)
			e.t = now + float(e.get("delay", 0.0))
			_shots.append(e)
			_shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	if not _shots.is_empty() and now >= float(_shots[0].t):
		_take(_shots.pop_front())
	elif _shots.is_empty() and _events.is_empty() and now >= _duration:
		get_tree().quit(0)
	elif now >= _duration + LATE:
		push_error("shot: never happened: %s" % ", ".join(_events.map(func(e: Dictionary) -> String: return e.name)))
		get_tree().quit(3)


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
