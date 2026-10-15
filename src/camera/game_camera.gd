class_name GameCamera
extends Camera2D
## Applies a `CameraRig` to the screen: hard follow at the anchor, aim look-ahead, zoom and
## shake (US-24, US-10). The rig holds the logic; this node only moves and scales the view.

var rig: CameraRig
## UI canvas height in points (360 in landscape with the project's stretch).
var canvas_height: float = 360.0


func setup(view_rules: ViewRules, settings: ControlSettings) -> void:
	rig = CameraRig.new(view_rules, settings)
	ignore_rotation = true
	position_smoothing_enabled = false


## One view frame: follow the body at `body` (world, interpolated between ticks).
func follow(body: Vector2, dt: float) -> void:
	rig.step(dt)
	var vp := get_viewport_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var world := rig.visible_world(aspect)
	zoom = Vector2.ONE * (vp.y / world.y)
	global_position = rig.center_for(body, aspect, canvas_height)


## The world rect the screen shows now (for the radar and name tags).
func view_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var world := vp / zoom
	return Rect2(global_position - world * 0.5, world)
