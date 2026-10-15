@tool
class_name Terrain
extends StaticBody2D
## Solid terrain: what toys stand on and bullets hit. Collision comes from the child
## `CollisionShape2D` (rectangles) and `CollisionPolygon2D` nodes. Until real art lands, the
## shapes draw themselves as flat blockout fills.

@export var fill: Color = Color(0.16, 0.13, 0.12)
@export var edge: Color = Color(0.05, 0.04, 0.04)
@export var draw_shapes: bool = true


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	queue_redraw()


func _draw() -> void:
	if not draw_shapes:
		return
	for c in get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var size: Vector2 = c.shape.size
			var r := Rect2(c.position - size * 0.5, size)
			draw_rect(r, fill)
			draw_rect(r, edge, false, 2.0)
		elif c is CollisionPolygon2D:
			var pts: PackedVector2Array = c.polygon
			var moved := PackedVector2Array()
			for p in pts:
				moved.append(c.transform * p)
			draw_colored_polygon(moved, fill)
			moved.append(moved[0])
			draw_polyline(moved, edge, 2.0)
