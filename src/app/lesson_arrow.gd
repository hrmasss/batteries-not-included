class_name LessonArrow
extends Control
## A bouncing arrow that points at the control a lesson step asks for (US-35.2).

var target: Vector2 = Vector2.ZERO
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	var dir := (target - centre).normalized() if target != centre else Vector2.DOWN
	var bob := sin(_t * 6.0) * 6.0
	var tip := target - dir * (34.0 + bob)
	var tail := tip - dir * 34.0
	var side := Vector2(-dir.y, dir.x)
	draw_line(tail, tip, Ui.ACCENT, 5.0, true)
	draw_colored_polygon(PackedVector2Array([tip + dir * 10.0, tip - dir * 4.0 + side * 9.0, tip - dir * 4.0 - side * 9.0]), Ui.ACCENT)
	draw_arc(target, 26.0 + bob * 0.5, 0.0, TAU, 32, Color(Ui.ACCENT, 0.7), 3.0, true)
