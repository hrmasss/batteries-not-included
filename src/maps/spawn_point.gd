@tool
class_name SpawnPoint
extends Marker2D
## Where a toy can spawn. The marker sits where the toy's feet go.

## Team that may spawn here in team modes; -1 for any team and free-for-all.
@export var team: int = -1


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.9, 0.3))
