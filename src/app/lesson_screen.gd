class_name LessonScreen
extends Node
## One lesson on the bedroom map: what to do, an arrow at the control to use, and Skip
## (US-35.2, US-35.3). Done moves on to the next lesson.

## The touch control each lesson step points at.
const CONTROLS := {
	&"move_stick": TouchLayout.Id.MOVE, &"aim_stick": TouchLayout.Id.AIM, &"pick_up": TouchLayout.Id.PICK_UP,
	&"switch": TouchLayout.Id.SWITCH, &"grenade": TouchLayout.Id.GRENADE,
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
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# Under the HUD's meters and clock.
	top.position = Vector2(0, 56)
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
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(_small("Back", app.show_lessons))
	buttons.add_child(_small("Skip", _next))
	top.add_child(buttons)
	_arrow = LessonArrow.new()
	_ui.add_child(_arrow)
	lesson.advanced.connect(func(_i: int) -> void: _show_step())
	lesson.finished.connect(_on_done)
	lesson.start(lesson_id)
	# Show the touch controls the lesson points at, even before a thumb is down.
	view.player_hud.touch.always_show = true
	_show_step.call_deferred()


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


## Where control `name` sits on screen, from the touch layout (US-35.2).
func _control_spot(control: StringName) -> Vector2:
	var touch := view.player_hud.touch
	if touch.layout == null:
		touch.apply_settings()
	return touch.layout.center(CONTROLS.get(control, TouchLayout.Id.MOVE))


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
