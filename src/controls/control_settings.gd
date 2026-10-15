class_name ControlSettings
extends RefCounted
## The player's own settings for controls, camera and sound (US-42.1, R1 part), kept on the
## phone across updates (US-42.2). Comfort only: nothing here changes a rule of the match.
##
## Camera comfort values start from the ruleset (T-81 to T-83) and only become the player's own
## once changed, so a ruleset change still reaches players who never touched them.

const PATH := "user://settings.cfg"
const VERSION := 1

enum ZoomMode { LAST_USED, KEEP, WIDEST }
enum LookAheadMode { ADAPTIVE, CONSTANT }

# Controls
## Stick size multiplier (US-23.5). Scales radius and drawing; capture grows with it.
var stick_size: float = 1.0
## Button size multiplier.
var button_size: float = 1.0
## Opacity of sticks and buttons, 0 to 1 (US-23.5). The classic's 200 of 255.
var opacity: float = 0.78
## US-23.3.
var floating_sticks: bool = false
## US-23.4: mirror sticks and buttons.
var left_handed: bool = false
## 0 none, 1 flip x, 2 flip y, 3 both.
var invert_move: int = 0
var invert_aim: int = 0
## US-05.7: a separate fire button; the aim stick then only aims.
var fire_button: bool = false
## Haptic tick on button presses.
var haptics: bool = true

# Camera. Negative means "the ruleset's value".
var look_ahead: float = -1.0
var look_ahead_mode: LookAheadMode = LookAheadMode.ADAPTIVE
var panning_speed: float = -1.0
var zoom_speed: float = -1.0
var zoom_mode: ZoomMode = ZoomMode.LAST_USED
## Screen shake multiplier, 0 off to 1 full (US-24.5).
var shake: float = 1.0

# Sound, 0 to 1.
var volume_master: float = 1.0
var volume_effects: float = 1.0
var volume_music: float = 0.7

const _KEYS: PackedStringArray = [
	"stick_size", "button_size", "opacity", "floating_sticks", "left_handed", "invert_move",
	"invert_aim", "fire_button", "haptics", "look_ahead", "look_ahead_mode", "panning_speed",
	"zoom_speed", "zoom_mode", "shake", "volume_master", "volume_effects", "volume_music",
]


func effective_look_ahead(v: ViewRules) -> float:
	return look_ahead if look_ahead >= 0.0 else v.look_ahead


func effective_panning(v: ViewRules) -> float:
	return panning_speed if panning_speed >= 0.0 else v.panning_speed


func effective_zoom_speed(v: ViewRules) -> float:
	return zoom_speed if zoom_speed >= 0.0 else v.zoom_speed


## Brings every value back into its allowed range, so a hand-edited or old file never breaks
## the game.
func clamp_all() -> void:
	stick_size = clampf(stick_size, 0.5, 2.0)
	button_size = clampf(button_size, 0.5, 2.0)
	opacity = clampf(opacity, 0.15, 1.0)
	invert_move = clampi(invert_move, 0, 3)
	invert_aim = clampi(invert_aim, 0, 3)
	look_ahead = -1.0 if look_ahead < 0.0 else clampf(look_ahead, 0.0, 2.0)
	panning_speed = -1.0 if panning_speed < 0.0 else clampf(panning_speed, 0.1, 60.0)
	zoom_speed = -1.0 if zoom_speed < 0.0 else clampf(zoom_speed, 0.0, 100.0)
	look_ahead_mode = clampi(look_ahead_mode, 0, LookAheadMode.size() - 1) as LookAheadMode
	zoom_mode = clampi(zoom_mode, 0, ZoomMode.size() - 1) as ZoomMode
	shake = clampf(shake, 0.0, 1.0)
	volume_master = clampf(volume_master, 0.0, 1.0)
	volume_effects = clampf(volume_effects, 0.0, 1.0)
	volume_music = clampf(volume_music, 0.0, 1.0)


func to_config() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for k in _KEYS:
		cfg.set_value("settings", k, get(k))
	return cfg


## Reads what it knows from `cfg` and keeps defaults for the rest; unknown keys are ignored, so
## a newer or older file still loads (US-42.2).
func read_config(cfg: ConfigFile) -> void:
	for k in _KEYS:
		if not cfg.has_section_key("settings", k):
			continue
		var want := typeof(get(k))
		var got: Variant = cfg.get_value("settings", k)
		if typeof(got) == want:
			set(k, got)
		elif want == TYPE_FLOAT and typeof(got) == TYPE_INT:
			set(k, float(got))
		elif want == TYPE_INT and typeof(got) == TYPE_FLOAT:
			set(k, int(got))
	clamp_all()


func save(path: String = PATH) -> Error:
	return to_config().save(path)


static func load_or_default(path: String = PATH) -> ControlSettings:
	var s := ControlSettings.new()
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(path) and cfg.load(path) == OK:
		s.read_config(cfg)
	return s


## Applies the volumes to the audio buses that exist ("Master", "Effects", "Music").
func apply_audio() -> void:
	_bus_volume("Master", volume_master)
	_bus_volume("Effects", volume_effects)
	_bus_volume("Music", volume_music)


static func _bus_volume(bus: String, share: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(share, 0.0001)))
		AudioServer.set_bus_mute(i, share <= 0.0)
