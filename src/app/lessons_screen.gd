class_name LessonsScreen
extends Control
## The lessons, in order (US-35.1): play any, replay any, skip any (US-35.3).

var app: App


func _init(owner_app: App) -> void:
	app = owner_app
	name = "LessonsScreen"


func _ready() -> void:
	var col := Ui.screen(self)
	col.add_child(Ui.label("LESSONS", Ui.FONT_BIG, Ui.ACCENT))
	col.add_child(Ui.label("Each one takes about a minute. Skip or replay any of them.", Ui.FONT_SMALL, Ui.TEXT_DIM))
	var first: Button = null
	var k := 0
	for id in LessonRunner.LESSONS:
		k += 1
		var done := app.settings.lessons_done.has(String(id))
		var b := Ui.button("%d. %s%s" % [k, LessonRunner.TITLES[id], "   ✓" if done else ""], app.start_lesson.bind(id), not done and first == null, 240)
		b.name = String(id)
		col.add_child(b)
		if first == null and not done:
			first = b
	col.add_child(Ui.button("Back", app.show_menu, false, 120))
	if first != null:
		first.grab_focus.call_deferred()
