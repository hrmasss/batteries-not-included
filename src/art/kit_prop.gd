@tool
class_name KitProp
extends Node2D
## One piece of a map kit (assets/maps/<kit>/kit.json), drawn from the kit's sheet. The node
## sits on the piece's origin: a prop's floor contact (its bottom-left), a shelf plank's
## top-left, the fan's ceiling mount. Playable pieces cast a soft copy of themselves on the
## wall behind (art lab: black at 16%, offset 70, -10 author px).
##
## Drawing only: the map's `Terrain` holds the collision, built from the same kit polygons by
## the map's generator (`tools/make_bedroom.gd`), so what you see is what you stand on.

const PX := 1.0 / ArtAtlas.AUTHOR_PX_PER_U
const SHADOW := Color(0.17, 0.2, 0.26, 0.16)
const SHADOW_OFFSET := Vector2(70, -10)

@export var piece: String = "":
	set(v):
		piece = v
		queue_redraw()
@export var flip: bool = false:
	set(v):
		flip = v
		queue_redraw()
## Uniform size factor, for toy-sized clutter that may vary.
@export var size_scale: float = 1.0:
	set(v):
		size_scale = v
		queue_redraw()
@export var cast_shadow: bool = true
@export var tint: Color = Color.WHITE

var _shadow: Node2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if cast_shadow and _kind() != "backdrop" and _kind() != "light":
		_shadow = Node2D.new()
		_shadow.z_index = -1
		_shadow.texture_filter = texture_filter
		_shadow.draw.connect(_draw_shadow)
		add_child(_shadow, false, Node.INTERNAL_MODE_FRONT)
	if _kind() == "light":
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


func _kind() -> String:
	return ArtLibrary.kit().get(piece, {}).get("kind", "prop")


func _atlas() -> ArtAtlas:
	var k := _kind()
	return ArtLibrary.bedroom(k == "backdrop" or k == "light")


## Local space <- the piece's image (author px from its top-left).
func image_xf() -> Transform2D:
	return image_xf_for(piece, flip, size_scale)


static func image_xf_for(id: String, flipped: bool, k: float = 1.0) -> Transform2D:
	var d: Dictionary = ArtLibrary.kit().get(id, {})
	var o: Array = d.get("origin", [0, 0])
	var origin := Vector2(float(o[0]), float(o[1]))
	var size := Vector2(float(d.size[0]), float(d.size[1])) if d.has("size") else Vector2.ZERO
	var s := PX * k
	if flipped:
		return Transform2D(0.0, Vector2(-s, s), 0.0, Vector2((size.x - origin.x) * s, -origin.y * s))
	return Transform2D(0.0, Vector2(s, s), 0.0, -origin * s)


func _draw() -> void:
	if piece == "":
		return
	draw_set_transform_matrix(image_xf())
	_atlas().draw(self, StringName(piece), Vector2.ZERO, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_shadow() -> void:
	var off := SHADOW_OFFSET * PX * size_scale
	_shadow.draw_set_transform_matrix(Transform2D(0.0, off) * image_xf())
	_atlas().draw(_shadow, StringName(piece), Vector2.ZERO, SHADOW)
	_shadow.draw_set_transform_matrix(Transform2D.IDENTITY)
