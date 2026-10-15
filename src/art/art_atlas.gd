class_name ArtAtlas
extends RefCounted
## One texture holding many pieces of art, rasterized from the art lab's SVGs when first asked
## for (Godot's own SVG renderer, the one `art/tools/check.py` checks against librsvg).
##
## Why at load and not as imported textures: one texture per family means a whole toy, its gun
## and its flash draw as one batch, and the raster density follows the screen (a 720 px phone
## does not pay for 1440 px art). The SVGs are imported as "keep", so they ship as they are.
##
## Units: the art is drawn in author px, 8 per world unit `u` (assets/README.md). A sheet keeps
## `texels_per_u` texels per u; `draw()` takes author-px rectangles, so callers never see texels.

const AUTHOR_PX_PER_U := 8.0
## Gap between pieces, texels: room for mipmaps without bleeding.
const PAD := 4
const MAX_WIDTH := 4096

## Sheets by key, built once per run.
static var _sheets: Dictionary = {}
## Texels per u for sheets built from now on. `set_density_for_screen` picks it.
static var texels_per_u: float = 3.0

var key: String = ""
var texture: ImageTexture
## Piece name -> Rect2 in texels.
var regions: Dictionary = {}
## Piece name -> size in author px (the SVG's own size).
var sizes: Dictionary = {}
var density: float = 3.0
## Milliseconds the build took, for the perf note.
var build_ms: int = 0


## Texels per u that match the screen: the standard view is 360 u tall (T-88), so a 1080 px tall
## screen shows 3 px per u. Kept between 2 and 4.
static func set_density_for_screen(screen_height: float) -> void:
	texels_per_u = clampf(roundf(screen_height / 360.0 * 2.0) / 2.0, 2.0, 4.0)


## The sheet for `key`, built from `files` (piece name -> res:// path of an SVG) on first use.
## `scale` multiplies the density, for art that may be softer (a muted backdrop).
static func sheet(sheet_key: String, files: Dictionary, scale: float = 1.0) -> ArtAtlas:
	if _sheets.has(sheet_key):
		return _sheets[sheet_key]
	var a := ArtAtlas.new()
	a.key = sheet_key
	a.density = texels_per_u * scale
	a._build(files)
	_sheets[sheet_key] = a
	return a


## Drops every built sheet (tests, or a density change).
static func clear() -> void:
	_sheets.clear()


func has(piece: StringName) -> bool:
	return regions.has(piece)


## Size of a piece in author px.
func size_of(piece: StringName) -> Vector2:
	return sizes.get(piece, Vector2.ZERO)


## Draws a piece onto `ci` with its top-left at `at` (author px in ci's current transform),
## optionally scaled. Callers set the transform with `draw_set_transform_matrix`.
func draw(ci: CanvasItem, piece: StringName, at: Vector2 = Vector2.ZERO, modulate: Color = Color.WHITE, scale: Vector2 = Vector2.ONE) -> void:
	var src: Rect2 = regions.get(piece, Rect2())
	if src.size == Vector2.ZERO:
		return
	ci.draw_texture_rect_region(texture, Rect2(at, size_of(piece) * scale), src, modulate)


func _build(files: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	var raster_scale := density / AUTHOR_PX_PER_U
	var images: Array = []
	for piece: StringName in files:
		var src := FileAccess.get_file_as_string(files[piece])
		if src.is_empty():
			push_error("ArtAtlas: cannot read %s" % files[piece])
			continue
		var img := Image.new()
		var err := img.load_svg_from_string(src, raster_scale)
		if err != OK:
			push_error("ArtAtlas: cannot raster %s (%s)" % [files[piece], error_string(err)])
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.fix_alpha_edges()
		images.append([piece, img])
		sizes[piece] = Vector2(img.get_size()) / raster_scale
	# Shelf packing, tallest first.
	images.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] as Image).get_height() > (b[1] as Image).get_height())
	var width := PAD
	for e: Array in images:
		width = maxi(width, (e[1] as Image).get_width() + PAD * 2)
	width = clampi(nearest_po2(maxi(width, 256)), 256, MAX_WIDTH)
	var x := PAD
	var y := PAD
	var row := 0
	var places: Array = []
	for e: Array in images:
		var img: Image = e[1]
		if x + img.get_width() + PAD > width:
			x = PAD
			y += row + PAD
			row = 0
		places.append(Vector2i(x, y))
		x += img.get_width() + PAD
		row = maxi(row, img.get_height())
	var height := nearest_po2(y + row + PAD)
	var sheet_img := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var img: Image = images[i][1]
		var at: Vector2i = places[i]
		sheet_img.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
		regions[images[i][0]] = Rect2(Vector2(at), Vector2(img.get_size()))
	sheet_img.generate_mipmaps()
	texture = ImageTexture.create_from_image(sheet_img)
	build_ms = Time.get_ticks_msec() - t0
