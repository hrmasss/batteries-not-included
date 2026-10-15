class_name LessonScreen
extends Node
## One lesson on the bedroom map: what to do, an arrow at the control to use, and Skip
## (US-35.2, US-35.3). Done moves on to the next lesson.

## Where the touch controls sit when the touch layout cannot say, as shares of the screen.
const SPOTS := {
	&"move_stick": Vector2(0.14, 0.78), &"aim_stick": Vector2(0.86, 0.78),
	&"pick_up": Vector2(0.70, 0.62), &"switch": Vector2(0.80, 0.08), &"grenade": Vector2(0.92, 0.50),
}

var app: App
var lesson_id: StringName
var view: GameView
var lesson: LessonRunner

var _ui: Control
var _text: Label
var _keys: Label
var _arrow: LessonArrow
var _intent: InputIntent = InputIntent.new()


func _init(owner_app: App, id: StringName) -> void:
	app = owner_app
	lesson_id = id
	name = "LessonScreen"


func _ready() -> void:
	view = GameView.new()
	view.name = "GameView"
	view.ruleset = app.rules
	view.show_overlay = app.settings.tuning_overlay
	add_child(view)
	lesson = LessonRunner.new(view.sim, view.me, func(team: int, feet: Vector2) -> Fighter: return view.add_dummy(team, feet, false))
	view.stepper = _step
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = Ui.theme()
	layer.add_child(_ui)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.position = Vector2(0, 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(top)
	top.add_child(Ui.label(LessonRunner.TITLES[lesson_id].to_upper(), Ui.FONT_SMALL, Ui.ACCENT))
	_text = Ui.label("", Ui.FONT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_text.add_theme_constant_override("outline_size", 4)
	top.add_child(_text)
	_keys = Ui.label("", Ui.FONT_SMALL, Ui.TEXT_DIM)
	_keys.visible = not OS.has_feature("mobile")
	top.add_child(_keys)
	var buttons := HBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_TOP_LEFT)
	buttons.position = Vector2(6, 6)
	buttons.add_child(_small("Back", app.show_lessons))
	buttons.add_child(_small("Skip", _next))
	_ui.add_child(buttons)
	_arrow = LessonArrow.new()
	_ui.add_child(_arrow)
	lesson.advanced.connect(func(_i: int) -> void: _show_step())
	lesson.finished.connect(_on_done)
	lesson.start(lesson_id)
	_show_step()


func _small(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.name = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(56, 24)
	b.add_theme_font_size_override("font_size", Ui.FONT_SMALL)
	b.pressed.connect(on_press)
	return b


func _step(intents: Dictionary) -> void:
	view.sim.step(intents)
	lesson.on_tick(intents.get(view.player.toy_id, InputIntent.idle()))


func _show_step() -> void:
	var s := lesson.step()
	if s == null:
		return
	_text.text = s.text
	_keys.text = s.keys
	_arrow.target = _control_spot(s.control)


## Where control `name` is on screen: the touch layout's own place when it has one.
func _control_spot(control: StringName) -> Vector2:
	var hud: Variant = view.get("player_hud")
	if hud != null and hud is Object and (hud as Object).has_method("control_center"):
		var at: Variant = (hud as Object).call("control_center", control)
		if at is Vector2:
			return at
	var share: Vector2 = SPOTS.get(control, Vector2(0.5, 0.5))
	return share * _ui.get_viewport_rect().size


func _on_done(id: StringName) -> void:
	app.settings.mark_lesson_done(id)
	_text.text = "Done!"
	_keys.text = ""
	_arrow.visible = false
	get_tree().create_timer(1.2).timeout.connect(_next)


func _next() -> void:
	var n := LessonRunner.next_of(lesson_id)
	if n == &"":
		app.show_lessons()
	else:
		app.start_lesson(n)
