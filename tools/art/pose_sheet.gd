extends SceneTree
## Renders the in-game soldier rig in its states on one sheet, from the game's own ToyView:
## stand, run, jump, fly, crouch, aim, recoil, flinch, dual guns, bare hands, a handless float,
## and every team mark. For eyeballing the rig and for proof. Needs a display:
##
##   xvfb-run -a godot --path . --resolution 1600x900 -s tools/art/pose_sheet.gd -- <out.png> [zoom]

var _out := ""
var _frames := 0
var _views: Array = []
var _rules: Ruleset
var _table: WeaponTable


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://pose_sheet.png"
	var zoom := float(args[1]) if args.size() > 1 else 3.0
	ArtAtlas.set_density_for_screen(360.0 * zoom)
	RenderingServer.set_default_clear_color(Color("e9e2d2"))
	_rules = RulesetLoader.load_dir(RulesetLoader.STANDARD_DIR).ruleset
	_table = _rules.weapons
	var cam := Camera2D.new()
	cam.zoom = Vector2(zoom, zoom) / (DisplayServer.window_get_size().y / 360.0)
	cam.position = Vector2(236, 132)
	root.add_child(cam)
	cam.make_current.call_deferred()
	var floor := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 10)
	cs.shape = rect
	floor.add_child(cs)
	floor.position = Vector2(250, 300)
	root.add_child(floor)
	var cells := [
		["stand", {}],
		["run", {"vel": Vector2(137, 0), "stick": Vector2(1, 0), "phase": 0.3}],
		["run b", {"vel": Vector2(137, 0), "stick": Vector2(1, 0), "phase": 1.9}],
		["jump", {"air": true, "vel": Vector2(60, -200)}],
		["fly", {"fly": true, "stick": Vector2(0.6, 0.8), "vel": Vector2(120, -120)}],
		["crouch", {"crouch": true}],
		["aim up", {"aim": Vector2(0.35, -0.94)}],
		["aim down", {"aim": Vector2(0.6, 0.8)}],
		["facing left", {"aim": Vector2(-1, -0.15)}],
		["recoil", {"kick": true}],
		["flinch, hurt", {"flinch": true}],
		["dual pistols", {"weapons": [&"pistol", &"uzi"]}],
		["bare hands", {"weapons": []}],
		["handless float", {"handless": true}],
		["shotgun", {"weapons": [&"pump_shotgun"]}],
		["rocket launcher", {"weapons": [&"rocket_launcher"]}],
		["team 1", {"team": 1, "fly": true, "stick": Vector2(-0.3, 1)}],
		["team 2", {"team": 2}],
		["team 3", {"team": 3}],
		["team 4", {"team": 4}],
		["free-for-all", {"team": 0}],
	]
	var cols := 7
	for i in cells.size():
		var c: Array = cells[i]
		var at := Vector2(20 + (i % cols) * 72, 40 + (i / cols) * 90)
		_add(c[0], c[1], at)


func _add(label: String, o: Dictionary, at: Vector2) -> void:
	var t := SimToy.new()
	t.build(_rules)
	t.position = at
	t.prev_position = at
	t.battery_max = 100.0
	t.battery = 100.0
	t.foot_contact = not o.get("air", false) and not o.get("fly", false)
	t.velocity = o.get("vel", Vector2.ZERO)
	t.stick = o.get("stick", Vector2.ZERO)
	t.stick_held = t.stick != Vector2.ZERO
	if o.get("fly", false):
		t.jetpack_on = true
		t.thrust = 0.9
	if o.get("crouch", false):
		t.set_crouched(true)
	root.add_child(t)
	var f := Fighter.new()
	f.toy = t
	f.team = int(o.get("team", 1))
	f.aim = (o.get("aim", Vector2(1, -0.05)) as Vector2).normalized()
	for id: StringName in o.get("weapons", [&"assault_rifle"]):
		f.weapons.append(WeaponItem.fresh(_table.get_def(id)))
	var v := ToyView.new(t, _rules)
	v.fixed_fighter = f
	v.animator.handless = o.get("handless", false)
	if o.has("phase"):
		v.animator.set("_phase", float(o.phase))
	root.add_child(v)
	var l := Label.new()
	l.text = label
	l.position = at + Vector2(-30, 26)
	l.scale = Vector2(0.25, 0.25)
	l.add_theme_color_override("font_color", Color("3a3442"))
	l.add_theme_font_size_override("font_size", 28)
	root.add_child(l)
	_views.append([v, o])


func _process(delta: float) -> bool:
	_frames += 1
	for e: Array in _views:
		var v: ToyView = e[0]
		var o: Dictionary = e[1]
		if o.has("phase"):
			v.animator.set("_phase", float(o.phase))
		if _frames == 40 and o.get("kick", false):
			v.animator.kick()
		if _frames == 39 and o.get("flinch", false):
			v.animator.flinch(v.toy.position.x + 50.0, v.toy.position.x)
		v.sync(1.0, 1.0 / 60.0)
	if _frames == 41:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		return true
	return false
