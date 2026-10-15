class_name MainMenu
extends Control
## The main menu: Bootcamp, Lessons, Settings. On first launch it offers the lessons, never
## forces them (US-35.4).

var app: App


func _init(owner_app: App) -> void:
	app = owner_app
	name = "MainMenu"


func _ready() -> void:
	var col := Ui.screen(self)
	col.add_child(Ui.label("BATTERIES NOT INCLUDED", Ui.FONT_TITLE, Ui.ACCENT))
	col.add_child(Ui.label("Toys strap on batteries and fight on the bedroom floor.", Ui.FONT_SMALL, Ui.TEXT_DIM))
	col.add_child(_gap(8))
	if not app.settings.lessons_offered:
		col.add_child(_offer())
	var start := Ui.button("Bootcamp", app.show_bootcamp, true, 220)
	start.name = "Bootcamp"
	col.add_child(start)
	var lessons := Ui.button("Lessons", app.show_lessons, false, 220)
	lessons.name = "Lessons"
	col.add_child(lessons)
	var settings := Ui.button("Settings", app.show_settings, false, 220)
	settings.name = "Settings"
	col.add_child(settings)
	if not OS.has_feature("mobile"):
		col.add_child(Ui.button("Quit", app.quit, false, 220))
	start.grab_focus.call_deferred()


func _offer() -> Control:
	var panel := PanelContainer.new()
	panel.name = "LessonOffer"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var col := VBoxContainer.new()
	panel.add_child(col)
	col.add_child(Ui.label("New here? The lessons teach the controls in a few minutes.", Ui.FONT_SMALL))
	col.add_child(Ui.row([
		Ui.button("Start the lessons", func() -> void:
			_offered()
			app.start_lesson(LessonRunner.LESSONS[0]), true, 170),
		Ui.button("Not now", func() -> void:
			_offered()
			panel.queue_free(), false, 100),
	]))
	return panel


func _offered() -> void:
	app.settings.lessons_offered = true
	app.settings.save()


static func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
