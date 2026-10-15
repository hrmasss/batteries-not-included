class_name SettingsScreen
extends Control
## Settings (US-42.1): the controls task's control, camera and sound settings, plus the app's
## own (the tuning overlay, the lessons). Every change is saved at once.

var app: App
var controls: ControlSettings


func _init(owner_app: App) -> void:
	app = owner_app
	name = "SettingsScreen"
	controls = ControlSettings.load_or_default()


func _ready() -> void:
	var page := Ui.screen(self)
	page.add_child(Ui.label("SETTINGS", Ui.FONT_BIG, Ui.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 250)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	var sizes := [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
	var shares := [0.0, 0.25, 0.5, 0.75, 1.0]
	var tenths := [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
	var on_off := [false, true]
	var flips := [0, 1, 2, 3]
	var flip_names := PackedStringArray(["Off", "Left-right", "Up-down", "Both"])
	_float(grid, "Stick size", "stick_size", sizes, _pct)
	_float(grid, "Button size", "button_size", sizes, _pct)
	_float(grid, "Opacity", "opacity", [0.2, 0.4, 0.6, 0.78, 0.9, 1.0], _pct)
	_pick(grid, "Floating sticks", "floating_sticks", on_off, ["Off", "On"])
	_pick(grid, "Left-handed", "left_handed", on_off, ["Off", "On"])
	_pick(grid, "Fire button", "fire_button", on_off, ["Off: fire at edge", "On"])
	_pick(grid, "Invert move", "invert_move", flips, flip_names)
	_pick(grid, "Invert aim", "invert_aim", flips, flip_names)
	_pick(grid, "Zoom on switch", "zoom_mode", [ControlSettings.ZoomMode.LAST_USED, ControlSettings.ZoomMode.KEEP, ControlSettings.ZoomMode.WIDEST], ["Last used", "Keep", "Widest"])
	_float(grid, "Screen shake", "shake", shares, _pct)
	_pick(grid, "Haptics", "haptics", on_off, ["Off", "On"])
	_float(grid, "Volume", "volume_master", tenths, _pct)
	_float(grid, "Effects", "volume_effects", tenths, _pct)
	_float(grid, "Music", "volume_music", tenths, _pct)
	var overlay := ChoiceRow.new("Tuning overlay", on_off, ["Hidden", "Shown"], app.settings.tuning_overlay)
	overlay.changed.connect(func(v: Variant) -> void:
		app.settings.tuning_overlay = v
		app.settings.save())
	grid.add_child(overlay)
	page.add_child(Ui.row([
		Ui.button("Back", app.show_menu, false, 100),
		Ui.button("Offer the lessons again", func() -> void:
			app.settings.lessons_offered = false
			app.settings.lessons_done = PackedStringArray()
			app.settings.save(), false, 200),
	]))


func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


func _float(grid: GridContainer, title: String, key: String, values: Array, fmt: Callable) -> void:
	var current: float = controls.get(key)
	if not values.has(current):
		values = values.duplicate()
		values.append(current)
		values.sort()
	_pick(grid, title, key, values, PackedStringArray(values.map(func(v: float) -> String: return fmt.call(v))))


func _pick(grid: GridContainer, title: String, key: String, values: Array, texts: PackedStringArray) -> void:
	var row := ChoiceRow.new(title, values, texts, controls.get(key))
	row.changed.connect(func(v: Variant) -> void:
		controls.set(key, v)
		controls.clamp_all()
		controls.save())
	grid.add_child(row)
