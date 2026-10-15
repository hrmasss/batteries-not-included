class_name App
extends Node
## The game app: the main menu, bootcamp, lessons, settings, and a match from start to results
## to rematch. One screen at a time; a match keeps its world drawn under the results.

var settings: AppSettings
var rules: Ruleset
var config: MatchConfig
var maps: Array[Dictionary] = []
## A bot plays the player's toy (recordings and soak runs; never on by default).
var autoplay: bool = false
## Where the app's settings live; tests point it elsewhere.
var settings_path: String = AppSettings.PATH

var _screen: Node = null
## Menu screens are Controls; they sit on this layer so they fill the screen.
var _layer: CanvasLayer


func _ready() -> void:
	InputActions.ensure()
	_layer = CanvasLayer.new()
	_layer.name = "Menus"
	add_child(_layer)
	settings = AppSettings.load_or_default(settings_path)
	var loaded := RulesetLoader.load_standard()
	if not loaded.ok():
		push_error("ruleset refused: %s" % "; ".join(loaded.errors))
		var c := Control.new()
		var col := Ui.screen(c)
		col.add_child(Ui.label("Ruleset refused:\n" + "\n".join(loaded.errors), Ui.FONT_SMALL, Color(1, 0.5, 0.5)))
		_show(c)
		return
	rules = loaded.ruleset
	maps = MapList.all()
	config = MatchConfig.defaults(rules)
	if not settings.last_bootcamp.is_empty():
		config.read(settings.last_bootcamp)
	config.clamp_to(rules)
	if maps.filter(func(m: Dictionary) -> bool: return m.path == config.map_path).is_empty() and not maps.is_empty():
		config.map_path = maps[0].path
	show_menu()


func _show(node: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = node
	if node is Control:
		_layer.add_child(node)
	else:
		add_child(node)


func show_menu() -> void:
	_show(MainMenu.new(self))


func show_bootcamp() -> void:
	_show(BootcampSetup.new(self))


func show_lessons() -> void:
	_show(LessonsScreen.new(self))


func show_settings() -> void:
	_show(SettingsScreen.new(self))


## Starts a bootcamp match on `cfg` (US-36.1).
func start_match(cfg: MatchConfig) -> void:
	config = cfg
	settings.last_bootcamp = cfg.to_dict()
	settings.save()
	_show(MatchScreen.new(self, cfg))


## US-20.4: the same players, teams and rules, a fresh roll of the dice.
func rematch() -> void:
	var cfg := config.copy()
	cfg.seed_value += 1
	start_match(cfg)


func start_lesson(id: StringName) -> void:
	_show(LessonScreen.new(self, id))


func quit() -> void:
	get_tree().quit()
