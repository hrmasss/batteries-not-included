extends SceneTree
## Builds maps/bedroom_blockout/bedroom_blockout.tscn. Run:
##   godot --headless --path . -s tools/make_blockout.gd
## Edit the layout here, re-run, commit the scene. Or open the scene in the editor and edit it
## there; then this script is only the starting point.

const OUT := "res://maps/bedroom_blockout/bedroom_blockout.tscn"
const FLOOR := 1216.0

## name, rect (x, y, w, h), y down. A tile is 64 u; a toy is about 45 u tall.
const SOLIDS := [
	["Floor", Rect2(-64, FLOOR, 2688, 96)],
	["WallLeft", Rect2(-64, -264, 64, 1576)],
	["WallRight", Rect2(2560, -264, 64, 1576)],
	["Ceiling", Rect2(-64, -264, 2688, 64)],
	["BedHeadboard", Rect2(288, 784, 40, 432)],
	["Bed", Rect2(288, 960, 672, 56)],
	["BedFoot", Rect2(920, 1016, 40, 200)],
	["ToyBox", Rect2(600, 1120, 160, 96)],
	["Nightstand", Rect2(1040, 1072, 160, 144)],
	["DeskTop", Rect2(1520, 896, 480, 32)],
	["DeskLegLeft", Rect2(1536, 928, 24, 288)],
	["DeskLegRight", Rect2(1960, 928, 24, 288)],
	["Chair", Rect2(1680, 1056, 128, 24)],
	["ChairBack", Rect2(1784, 928, 24, 128)],
	["Wardrobe", Rect2(2304, 640, 256, 576)],
	["ShelfLeft", Rect2(0, 560, 256, 24)],
	["ShelfHigh", Rect2(1088, 400, 320, 24)],
	["ShelfRight", Rect2(1792, 512, 288, 24)],
	["Bookend", Rect2(1792, 448, 24, 64)],
]

## name, feet position, team
const SPAWNS := [
	["Spawn1", Vector2(160, FLOOR), -1],
	["Spawn2", Vector2(1300, FLOOR), -1],
	["Spawn3", Vector2(620, 960), -1],
	["Spawn4", Vector2(1760, 896), -1],
	["Spawn5", Vector2(2430, 640), -1],
	["Spawn6", Vector2(128, 560), -1],
]

## name, position, items, own interval (-1: the match's)
const PICKUPS := [
	["PickupBed", Vector2(800, 960), ["uzi", "smg"], -1.0],
	["PickupShelf", Vector2(1248, 400), ["sniper_rifle"], 90.0],
	["PickupDesk", Vector2(1640, 896), ["frag"], 30.0],
	["PickupFloor", Vector2(1400, FLOOR), ["health_pack", "battery_pack"], -1.0],
	["PickupShelfLeft", Vector2(200, 560), ["assault_rifle", "pump_shotgun"], -1.0],
	["PickupShelfRight", Vector2(1950, 512), ["pump_shotgun", "uzi"], -1.0],
	["PickupToyBox", Vector2(680, 1120), ["frag", "health_pack"], 30.0],
	# The rocket launcher is a rare pickup (US-11.1): one draw in four, every two minutes.
	["PickupWardrobe", Vector2(2350, 640), ["rocket_launcher", "assault_rifle", "pump_shotgun", "smg"], 120.0],
]

## name, position, team, kind
const BASES := [
	["BaseTeam0", Vector2(96, FLOOR), 0, "flag"],
	["BaseTeam1", Vector2(2432, 640), 1, "flag"],
]


func _init() -> void:
	var root := GameMap.new()
	root.name = "BedroomBlockout"
	root.display_name = "Bedroom (blockout)"
	root.bounds = Rect2(-64, -264, 2688, 1576)

	var backdrop := Node2D.new()
	backdrop.name = "Backdrop"
	backdrop.set_script(load("res://maps/bedroom_blockout/backdrop.gd"))
	_add(root, root, backdrop)

	var terrain := Terrain.new()
	terrain.name = "Terrain"
	_add(root, root, terrain)
	for s: Array in SOLIDS:
		var cs := CollisionShape2D.new()
		cs.name = s[0]
		var shape := RectangleShape2D.new()
		var r: Rect2 = s[1]
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		_add(root, terrain, cs)

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	_add(root, root, spawns)
	for s: Array in SPAWNS:
		var p := SpawnPoint.new()
		p.name = s[0]
		p.position = s[1]
		p.team = s[2]
		_add(root, spawns, p)

	var pickups := Node2D.new()
	pickups.name = "Pickups"
	_add(root, root, pickups)
	for s: Array in PICKUPS:
		var p := PickupPoint.new()
		p.name = s[0]
		p.position = s[1]
		p.items = PackedStringArray(s[2])
		p.interval = s[3]
		_add(root, pickups, p)

	var bases := Node2D.new()
	bases.name = "Bases"
	_add(root, root, bases)
	for s: Array in BASES:
		var b := TeamBase.new()
		b.name = s[0]
		b.position = s[1]
		b.team = s[2]
		b.kind = s[3]
		_add(root, bases, b)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("saved %s: %s" % [OUT, error_string(err)])
	root.free()
	quit(0 if err == OK else 1)


func _add(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root
