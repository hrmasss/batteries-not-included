@tool
extends Node2D
## Flat, pale, muted bedroom wall behind the play terrain (docs/art "Punch": dark terrain
## against a pale backdrop). Blockout only: no collision, no detail.

@export var area: Rect2 = Rect2(-64, -264, 2688, 1576)
@export var wall: Color = Color(0.91, 0.88, 0.81)
@export var stripe: Color = Color(0.87, 0.84, 0.77)
@export var trim: Color = Color(0.8, 0.76, 0.69)


func _ready() -> void:
	z_index = -10
	queue_redraw()


func _draw() -> void:
	draw_rect(area, wall)
	var x := area.position.x
	while x < area.end.x:
		draw_rect(Rect2(x, area.position.y, 48.0, area.size.y), stripe)
		x += 128.0
	# Window with a night sky, a poster, a skirting board.
	draw_rect(Rect2(820, 200, 360, 300), trim)
	draw_rect(Rect2(836, 216, 328, 268), Color(0.2, 0.24, 0.36))
	draw_rect(Rect2(996, 216, 8, 268), trim)
	draw_rect(Rect2(836, 346, 328, 8), trim)
	draw_circle(Vector2(1100, 270), 22.0, Color(0.93, 0.92, 0.8))
	draw_rect(Rect2(1460, 300, 180, 240), Color(0.8, 0.62, 0.55))
	draw_rect(Rect2(1476, 316, 148, 208), Color(0.86, 0.74, 0.6))
	draw_rect(Rect2(area.position.x, 1176, area.size.x, 40), trim)
