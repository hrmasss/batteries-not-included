@tool
class_name TeamBase
extends Marker2D
## A team's base for flag and bomb modes (R2).

@export var team: int = 0
## "flag" for capture the flag, "bomb_site" for plant the bomb.
@export var kind: String = "flag"


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-10, -20, 20, 20), Color(0.3, 0.5, 1.0), false, 2.0)
