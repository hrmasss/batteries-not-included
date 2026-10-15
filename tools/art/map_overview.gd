extends SceneTree
## Renders a whole map at once, with its collision drawn over it when asked, for checking that
## the terrain matches the drawn props. Needs a display:
##
##   xvfb-run -a godot --path . --resolution 1920x820 -s tools/art/map_overview.gd -- <map.tscn> <out.png> [collision]

var _out := ""
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map: GameMap = load(args[0]).instantiate()
	_out = args[1]
	root.add_child(map)
	if args.size() > 2 and args[2] == "collision":
		for t in map.get_children():
			if t is Terrain:
				t.draw_shapes = true
				t.fill = Color(1, 0.1, 0.3, 0.35)
				t.edge = Color(1, 0.1, 0.3, 0.9)
				t.z_index = 50
				t.queue_redraw()
		for s in map.spawn_points():
			var m := Polygon2D.new()
			m.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(0, -40)])
			m.color = Color(0.2, 0.9, 0.3, 0.9)
			m.position = s.position
			m.z_index = 60
			root.add_child(m)
		for p in map.pickup_points():
			var m := Polygon2D.new()
			m.polygon = PackedVector2Array([Vector2(-8, -16), Vector2(8, -16), Vector2(8, 0), Vector2(-8, 0)])
			m.color = Color(1, 0.85, 0.1, 0.9)
			m.position = p.position
			m.z_index = 60
			root.add_child(m)
	var cam := Camera2D.new()
	var b := map.bounds
	cam.position = b.get_center()
	var view := Vector2(640, 360) * Vector2(DisplayServer.window_get_size()) / DisplayServer.window_get_size().y
	var z := minf(view.x / b.size.x, view.y / b.size.y)
	cam.zoom = Vector2(z, z)
	root.add_child(cam)
	cam.make_current.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("saved ", _out)
		return true
	return false
