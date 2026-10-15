class_name GameCamera
extends Camera2D
## The match camera (US-24, US-10): hard follow with the toy a little below the middle (T-84),
## aim look-ahead by the held weapon (T-81, T-82), the zoom ladder (T-80, T-83) and blast shake.
## Every screen shape sees the same world area as a 16:9 screen showing `view_height` (T-88).
##
## The logic lives in `CameraRig`; this node only moves and scales the view.

const BASE_ASPECT := CameraRig.BASE_ASPECT

var rules: Ruleset
var rig: CameraRig


func _init(ruleset: Ruleset = null, settings: ControlSettings = null) -> void:
	rules = ruleset
	position_smoothing_enabled = false
	ignore_rotation = true
	if ruleset != null:
		rig = CameraRig.new(ViewRules.from_ruleset(ruleset), settings if settings != null else ControlSettings.load_or_default())


## Zoom that shows the T-88 area on this viewport, at the current zoom level.
func area_zoom() -> float:
	var vp := get_viewport_rect().size
	return vp.y / rig.visible_world(vp.x / maxf(vp.y, 1.0)).y


## One view frame: follow the toy body drawn at `target`. `dt` defaults to the frame time.
func follow(target: Vector2, dt: float = -1.0) -> void:
	rig.step(dt if dt >= 0.0 else get_process_delta_time())
	var vp := get_viewport_rect().size
	var z := area_zoom()
	zoom = Vector2(z, z)
	# The UI canvas is the viewport's own canvas, so its height is the viewport height.
	position = rig.center_for(target, vp.x / maxf(vp.y, 1.0), vp.y)


## The world rect the screen shows now (for the radar).
func view_rect() -> Rect2:
	var world := get_viewport_rect().size / zoom
	return Rect2(get_screen_center_position() - world * 0.5, world)
