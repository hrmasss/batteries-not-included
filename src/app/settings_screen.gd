class_name SettingsScreen
extends Control
## Settings: the app's own (the tuning overlay, lessons) for now; the controls task's
## control and camera settings join here once they land.

var app: App


func _init(owner_app: App) -> void:
	app = owner_app
	name = "SettingsScreen"


func _ready() -> void:
	var col := Ui.screen(self)
	col.add_child(Ui.label("SETTINGS", Ui.FONT_BIG, Ui.ACCENT))
	var overlay := ChoiceRow.new("Tuning overlay", [false, true], ["Hidden", "Shown (F1 toggles, F2 hitboxes)"], app.settings.tuning_overlay)
	overlay.changed.connect(func(v: Variant) -> void:
		app.settings.tuning_overlay = v
		app.settings.save())
	col.add_child(overlay)
	col.add_child(Ui.button("Offer the lessons again", func() -> void:
		app.settings.lessons_offered = false
		app.settings.lessons_done = PackedStringArray()
		app.settings.save(), false, 240))
	col.add_child(Ui.button("Back", app.show_menu, false, 120))
