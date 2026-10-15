extends Node
## Drives the whole app (menus, a match, results) from a plan and saves screenshots, for proof
## clips. Run by tools/app_shot.sh; reads options after `--`: --plan <json> --out <dir>.
##
## Plan JSON:
##   {
##     "autoplay": true,                  a bot plays the player's toy
##     "fresh": true,                     start with default app settings
##     "config": {"length": 60, ...},     bootcamp setup to start from (MatchConfig keys)
##     "steps": [
##       {"t": 1.0, "shot": "menu"},              screenshot at t s after the start
##       {"t": 2.0, "press": "Bootcamp"},         press the button with this node name
##       {"when": "results", "delay": 1.5, "shot": "results"},   once the results show
##       {"when": "results", "delay": 4.0, "press": "Rematch"},
##       {"when": "match", "delay": 3.0, "shot": "rematch"},     once a new match runs
##       {"when": "lesson", "delay": 2.0, "shot": "fly"},        once a new lesson runs
##       {"t": 99, "quit": true}
##     ]
##   }
## A step with "when" waits for that and counts its delay from then. Steps run in order.

var _app: App
var _steps: Array = []
var _out: String = ""
var _t: float = 0.0
var _since: float = -1.0
var _busy: bool = false
var _last_screen: Node = null


func _ready() -> void:
	var args := _args()
	_out = args.get("out", "user://app_shots")
	DirAccess.make_dir_recursive_absolute(_out)
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(args.get("plan", "")))
	if typeof(plan) != TYPE_DICTIONARY:
		push_error("app_shot: cannot read plan")
		get_tree().quit(2)
		return
	_steps = plan.get("steps", [])
	if bool(plan.get("fresh", true)):
		DirAccess.remove_absolute(AppSettings.PATH)
	_app = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	_app.autoplay = bool(plan.get("autoplay", false))
	add_child(_app)
	if plan.has("config"):
		_app.config.read(plan.config)
		_app.config.clamp_to(_app.rules)


func _process(delta: float) -> void:
	_t += delta
	if _busy or _steps.is_empty():
		return
	var s: Dictionary = _steps[0]
	if s.has("when"):
		if _since < 0.0:
			if not _happened(s.when):
				return
			_since = _t
		if _t - _since < float(s.get("delay", 0.0)):
			return
	elif _t < float(s.get("t", 0.0)):
		return
	_steps.pop_front()
	_since = -1.0
	_do(s)


func _happened(what: String) -> bool:
	var screen := _current()
	match what:
		"results":
			return screen is MatchScreen and screen.find_child("Results", true, false) != null
		"match":
			if screen is MatchScreen and screen != _last_screen:
				_last_screen = screen
				return true
			return false
		"menu":
			return screen is MainMenu
		"lesson":
			if screen is LessonScreen and screen != _last_screen:
				_last_screen = screen
				return true
			return false
		"setup":
			return screen is BootcampSetup
	return false


func _current() -> Node:
	return _app._screen


func _do(s: Dictionary) -> void:
	if s.has("press"):
		var b := _current().find_child(String(s.press), true, false)
		if b is BaseButton:
			print("app_shot: press %s at %.1f s" % [s.press, _t])
			(b as BaseButton).pressed.emit()
		else:
			push_error("app_shot: no button %s" % s.press)
	if s.has("step_choice"):
		var row := _current().find_child(String(s.step_choice), true, false)
		if row is ChoiceRow:
			for k in int(s.get("by", 1)):
				(row as ChoiceRow).step(1)
	if s.has("scores"):
		var m := _current()
		if m is MatchScreen:
			(m as MatchScreen)._hold_scores = bool(s.scores)
	if s.has("shot"):
		_busy = true
		await RenderingServer.frame_post_draw
		var path := _out.path_join("%s.png" % s.shot)
		var err := get_viewport().get_texture().get_image().save_png(path)
		print("app_shot: shot %s at %.1f s: %s" % [path, _t, error_string(err)])
		_busy = false
	if s.has("quit"):
		get_tree().quit(0)


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
