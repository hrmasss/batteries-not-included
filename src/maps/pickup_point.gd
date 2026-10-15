@tool
class_name PickupPoint
extends Marker2D
## A place pickups appear (01_world "Pickups"). Each time the point is empty and its interval
## passes, one item id from `items` is drawn at random (T-76).

## Item ids that may appear here: weapons by id, "frag", "health_pack", "battery_pack".
@export var items: PackedStringArray = []
## Own respawn interval in seconds; -1 uses the match's setting (T-76).
@export var interval: float = -1.0


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-6, -6, 12, 12), Color(0.9, 0.8, 0.2))
