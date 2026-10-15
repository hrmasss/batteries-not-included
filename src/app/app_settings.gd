class_name AppSettings
extends RefCounted
## The app's own choices, kept on the phone: whether the tuning overlay shows, whether the
## lessons were offered and which are done (US-35.4), and the last bootcamp setup.
## Control and camera settings are the controls task's (`ControlSettings`).

const PATH := "user://app.cfg"

## The tuning overlay (US-37) and the debug keys, hidden unless turned on here.
var tuning_overlay: bool = false
## The lessons were offered once on first launch; never forced (US-35.4).
var lessons_offered: bool = false
var lessons_done: PackedStringArray = []
var last_bootcamp: Dictionary = {}
## Demo recordings only, set by hand in the file ([debug] autoplay=true): a bot plays the
## player's toy. No screen offers it.
var autoplay: bool = false

var _path: String = PATH


static func load_or_default(path: String = PATH) -> AppSettings:
	var s := AppSettings.new()
	s._path = path
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(path) and cfg.load(path) == OK:
		s.tuning_overlay = bool(cfg.get_value("app", "tuning_overlay", false))
		s.lessons_offered = bool(cfg.get_value("app", "lessons_offered", false))
		var done: Variant = cfg.get_value("app", "lessons_done", PackedStringArray())
		s.lessons_done = PackedStringArray(done) if done is PackedStringArray or done is Array else PackedStringArray()
		var last: Variant = cfg.get_value("app", "last_bootcamp", {})
		s.last_bootcamp = last if last is Dictionary else {}
		s.autoplay = bool(cfg.get_value("debug", "autoplay", false))
	return s


func save() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("app", "tuning_overlay", tuning_overlay)
	cfg.set_value("app", "lessons_offered", lessons_offered)
	cfg.set_value("app", "lessons_done", lessons_done)
	cfg.set_value("app", "last_bootcamp", last_bootcamp)
	if autoplay:
		cfg.set_value("debug", "autoplay", true)
	return cfg.save(_path)


func mark_lesson_done(id: StringName) -> void:
	if not lessons_done.has(String(id)):
		lessons_done.append(String(id))
		save()
