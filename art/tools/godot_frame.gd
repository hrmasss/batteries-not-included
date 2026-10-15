extends SceneTree
## Rebuild a composed scene in Godot from the assets and save a screenshot.
##
## The scene comes from art/tools/frame.py (a json list of placements). Each SVG is
## rasterized by Godot's own importer code at the scale it is shown at, glow items use
## additive blending, and each toy sits in a CanvasGroup with an outline shader for its
## team colour, the way the game can do it.
##
## godot --rendering-method gl_compatibility --resolution 1280x720 --path <tmp project> \
##   -s godot_frame.gd -- <repo root> <scene.json> <out.png>

const OUTLINE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform float line_thickness = 1.5;
uniform vec4 line_colour : source_color = vec4(1.0);
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
	vec2 size = SCREEN_PIXEL_SIZE * line_thickness;
	float outline = 0.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 6.2831853 / 12.0;
		outline += texture(screen_texture, SCREEN_UV + vec2(cos(a), sin(a)) * size).a;
	}
	outline = min(outline, 1.0);
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	COLOR = mix(c, line_colour, outline - c.a);
}
"""

const FLAT_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
"""

var _frames := 0
var _out := ""
var _view_scale := 0.25
var _cache := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var root_dir: String = args[0]
	var scene: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	_out = args[2]
	_view_scale = float(scene["view"][0]) / float(scene["size"][0])
	RenderingServer.set_default_clear_color(Color.html(scene["clear"]))
	var world := Node2D.new()
	root.add_child(world)
	var parent: Node = world
	var outline_shader := Shader.new()
	outline_shader.code = OUTLINE_SHADER
	var flat_shader := Shader.new()
	flat_shader.code = FLAT_SHADER
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for item in scene["items"]:
		var kind: String = item["kind"]
		if kind == "group_begin":
			var g := CanvasGroup.new()
			g.fit_margin = 8.0
			g.clear_margin = 8.0
			var mat := ShaderMaterial.new()
			mat.shader = outline_shader
			mat.set_shader_parameter("line_colour", Color.html(item["outline"]))
			mat.set_shader_parameter("line_thickness", float(item["width"]) * _view_scale)
			g.material = mat
			world.add_child(g)
			parent = g
			continue
		if kind == "group_end":
			parent = world
			continue
		var sprite: Sprite2D
		if kind == "raw":
			var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % [
				scene["size"][0], scene["size"][1], scene["size"][0], scene["size"][1], item["svg"]]
			sprite = _sprite(svg, [0.0, 0.0], [1, 0, 0, 1, 0, 0])
		else:
			var src := FileAccess.get_file_as_string(root_dir.path_join(item["path"]))
			sprite = _sprite(src, _viewbox_origin(src), item["m"])
			if kind == "flat":
				var fm := ShaderMaterial.new()
				fm.shader = flat_shader
				var col := Color.html(item["colour"])
				col.a = float(item["opacity"])
				fm.set_shader_parameter("tint", col)
				sprite.material = fm
			elif float(item.get("opacity", 1.0)) < 1.0:
				sprite.modulate.a = float(item["opacity"])
		if item.get("blend", "normal") == "add":
			sprite.material = add_mat
		parent.add_child(sprite)


func _viewbox_origin(src: String) -> Array:
	var re := RegEx.new()
	re.compile('viewBox="([^"]+)"')
	var parts := re.search(src).get_string(1).split(" ", false)
	return [float(parts[0]), float(parts[1])]


func _sprite(src: String, vb0: Array, m: Array) -> Sprite2D:
	# raster at the scale the item is shown at on screen, like an import at that scale
	var s: float = sqrt(abs(float(m[0]) * float(m[3]) - float(m[1]) * float(m[2]))) * _view_scale
	s = max(s, 0.01)
	var key := "%d:%f" % [src.hash(), s]
	var tex: Texture2D
	if _cache.has(key):
		tex = _cache[key]
	else:
		var img := Image.new()
		img.load_svg_from_string(src, s)
		tex = ImageTexture.create_from_image(img)
		_cache[key] = tex
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	# screen = view * M * translate(vb0) * scale(1/s) * pixel
	var xf_m := Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5]))
	var xf := Transform2D(0.0, Vector2(_view_scale, _view_scale), 0.0, Vector2.ZERO) * xf_m \
		* Transform2D(0.0, Vector2(vb0[0], vb0[1])) * Transform2D(0.0, Vector2(1.0 / s, 1.0 / s), 0.0, Vector2.ZERO)
	sp.transform = xf
	return sp


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out, " ", img.get_size())
		return true
	return false
