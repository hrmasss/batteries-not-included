class_name NameTag
extends Node2D
## A player's name over their toy, with the team colour and team shape (US-26.3). Shown when the
## toy is near the viewer; fades out past `near`.
##
## Place it as a sibling of the toy's drawing and set `target`; it follows in world space and
## keeps its size on screen whatever the zoom.

## Full opacity within this distance of the viewer, gone by 1.25 × it, u. Ours (US-26.3 "near").
@export var near: float = 450.0
## Above the body origin, u.
@export var height: float = 52.0

var player_name: String = ""
var team: int = -1
## The toy to follow (any Node2D) and the viewer's toy, for the distance.
var target: Node2D
var viewer: Node2D


func _process(_dt: float) -> void:
	# No tag over a toy that is not drawn (popped and waiting to respawn).
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		visible = false
		return
	global_position = target.global_position + Vector2(0, -height)
	var a := 1.0
	if viewer != null and is_instance_valid(viewer) and viewer != target:
		var d := viewer.global_position.distance_to(target.global_position)
		a = clampf((near * 1.25 - d) / (near * 0.25), 0.0, 1.0)
	modulate.a = a
	visible = a > 0.0
	# Constant screen size whatever the camera zoom.
	var cam := get_viewport().get_camera_2d()
	var z := cam.zoom.x if cam != null else 1.0
	scale = Vector2.ONE / maxf(z, 0.01) * _ui_scale()
	queue_redraw()


func _ui_scale() -> float:
	# One UI point in viewport pixels; the HUD canvas is 360 points tall in landscape.
	var vp := get_viewport_rect().size
	return minf(vp.x, vp.y) / 360.0


func _draw() -> void:
	if player_name == "":
		return
	var size := 11
	var w := HudStyle.text_width(player_name, size)
	var col := TeamPalette.color(team)
	var shape_w := 12.0
	var total := w + shape_w + 6.0
	var left := -total * 0.5
	var plate := Rect2(left - 5.0, -12.0, total + 10.0, 16.0)
	HudStyle.slab(self, plate, Color(HudStyle.INK, 0.55), 6.0, 1.5)
	draw_rect(Rect2(plate.position.x + 4.0, plate.end.y - 3.0, plate.size.x - 8.0, 2.0), col)
	TeamPalette.draw_shape(self, team, Vector2(left + 5.0, -4.0), 4.5)
	HudStyle.text(self, Vector2(left + shape_w + 2.0, 0.0), player_name, size, HudStyle.TEXT)
