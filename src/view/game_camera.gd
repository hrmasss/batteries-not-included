class_name GameCamera
extends Camera2D
## Hard follow with the toy a little below the middle (T-84). Every screen shape sees the same
## world area as a 16:9 screen showing `view_height` (T-88).

const BASE_ASPECT := 16.0 / 9.0

var rules: Ruleset


func _init(ruleset: Ruleset = null) -> void:
	rules = ruleset
	position_smoothing_enabled = false


## Zoom that shows the T-88 area on this viewport, at 1X.
func area_zoom() -> float:
	var visible := get_viewport_rect().size
	var area := rules.view_height * rules.view_height * BASE_ASPECT
	return sqrt(visible.x * visible.y / area)


func follow(target: Vector2) -> void:
	var z := area_zoom()
	zoom = Vector2(z, z)
	position = target - Vector2(0.0, rules.anchor_below_middle / z)
