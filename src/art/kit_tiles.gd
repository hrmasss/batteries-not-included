@tool
class_name KitTiles
extends Node2D
## A kit tile repeated over an area: the wallpaper (both ways), the floor and the skirting
## (along x). Tiles sit with their origin on the area's top-left row, or, for `along_x`, on
## the area's bottom-left like props on a floor line. World units.

const PX := 1.0 / ArtAtlas.AUTHOR_PX_PER_U

@export var piece: String = "wall_tile":
	set(v):
		piece = v
		queue_redraw()
@export var area: Rect2 = Rect2(0, 0, 512, 512):
	set(v):
		area = v
		queue_redraw()
## Repeat along x only, with the tile's origin on the area's bottom edge.
@export var along_x: bool = false
@export var tint: Color = Color.WHITE
## Light over the tiles, top to bottom: a soft wash that gives the flat wall some depth.
@export var wash_top: Color = Color(0, 0, 0, 0)
@export var wash_bottom: Color = Color(0, 0, 0, 0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
	var d: Dictionary = ArtLibrary.kit().get(piece, {})
	if d.is_empty():
		return
	var back: bool = d.kind == "backdrop" or d.kind == "light"
	var atlas := ArtLibrary.bedroom(back)
	var size := Vector2(float(d.size[0]), float(d.size[1])) * PX
	var o := Vector2(float(d.origin[0]), float(d.origin[1])) * PX
	# One texel of overlap so seams never show between tiles.
	var step := size - Vector2(1, 1) * PX * 2.0
	if along_x:
		var x := area.position.x
		while x < area.end.x:
			draw_set_transform(Vector2(x, area.end.y) - o, 0.0, Vector2(PX, PX))
			atlas.draw(self, StringName(piece), Vector2.ZERO, tint)
			x += step.x
	else:
		var y := area.position.y
		while y < area.end.y:
			var x := area.position.x
			while x < area.end.x:
				draw_set_transform(Vector2(x, y), 0.0, Vector2(PX, PX))
				atlas.draw(self, StringName(piece), Vector2.ZERO, tint)
				x += step.x
			y += step.y
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if wash_top.a > 0.0 or wash_bottom.a > 0.0:
		var r := area
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([wash_top, wash_top, wash_bottom, wash_bottom]))
