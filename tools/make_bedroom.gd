extends SceneTree
## Builds maps/bedroom/bedroom.tscn from the art lab's bedroom kit (assets/maps/bedroom/kit.json):
## every prop drawn from the kit, and its collision polygons from the same file, so the terrain
## matches the drawn props (US-38.4). Run:
##   godot --headless --path . -s tools/make_bedroom.gd
## Edit the layout here, re-run, commit the scene.
##
## World units: 8 author px per u (assets/README.md), so the soldier is a 12 cm toy and the bed
## a real bed. Floor walking line at y = 0, ceiling at y = -CEILING, room ROOM wide. Kit
## "platform" polygons are solid like the rest: the sim has no one-way terrain, and in the
## classic all terrain is solid.

const OUT := "res://maps/bedroom/bedroom.tscn"
const ROOM := 2560.0
const CEILING := 1040.0
## Floor art below the walking line, u (kit floor: 180 px solid, 278 - 94 drawn).
const FLOOR_DEPTH := 23.0
const WALL_SCROLL := Vector2(0.9, 0.94)
const PX := 1.0 / 8.0

## piece, origin position (u), flip, size scale
const PROPS := [
	["bookshelf", Vector2(4, 0), false],
	["bed", Vector2(300, 0), false],
	["book_stack", Vector2(876, 0), false],
	["block_star", Vector2(1000, 0), false],
	["block_moon", Vector2(1027, 0), false],
	["block_heart", Vector2(1013, -26.25), false],
	["toy_chest", Vector2(1110, 0), false],
	["block_heart", Vector2(1410, 0), false],
	["desk", Vector2(1560, 0), false],
	["block_moon", Vector2(2015, 0), false],
	["book_stack", Vector2(2140, 0), true],
	["bookshelf", Vector2(2320, 0), true],
	["wall_shelf", Vector2(420, -470), false],
	["wall_shelf", Vector2(80, -640), true],
	["wall_shelf", Vector2(760, -720), false],
	["wall_shelf", Vector2(1180, -820), true],
	["wall_shelf", Vector2(1540, -600), false],
	["wall_shelf", Vector2(1890, -780), true],
	["wall_shelf", Vector2(2090, -470), false],
	["wall_shelf", Vector2(2320, -650), false],
	["ceiling_fan", Vector2(1280, -CEILING), false],
]

## Backdrop pieces: where they should appear when the camera looks at them (u).
const BACK := [
	["window", Vector2(1090, -600)],
	["poster", Vector2(1990, -640)],
	["poster", Vector2(560, -820)],
]

## name, x, drop from y: the spawn lands on the first surface below.
const SPAWNS := [
	["FloorLeft", 268, -40], ["UnderBed", 560, -40], ["FloorBlocks", 1076, -10], ["FloorMid", 1480, -10],
	["UnderDesk", 1700, -40], ["FloorRight", 2240, -10],
	["Bed", 600, -400], ["Chest", 1230, -400], ["Desk", 1760, -400],
	["ShelfTopLeft", 120, -500], ["ShelfTopRight", 2436, -500],
	["ShelfHighLeft", 860, -900], ["ShelfHighRight", 1990, -900], ["ShelfMidRight", 2190, -560],
]

## name, x, drop from y, items, own interval (-1: the match's)
const PICKUPS := [
	["UnderBed", 700, -40, ["uzi", "smg"], -1.0],
	["Pillow", 470, -400, ["frag", "health_pack"], 30.0],
	["ShelfWindow", 1278, -900, ["sniper_rifle"], 90.0],
	# The rocket launcher is a rare pickup (US-11.1): one draw in four, every two minutes.
	["Fan", 1160, -1035, ["rocket_launcher", "assault_rifle", "pump_shotgun", "smg"], 120.0],
	["DeskTop", 1660, -400, ["frag"], 30.0],
	["FloorMid", 1300, -10, ["health_pack", "battery_pack"], -1.0],
	["ShelfOverBed", 520, -560, ["assault_rifle", "pump_shotgun"], -1.0],
	["ShelfRight", 2180, -560, ["pump_shotgun", "uzi"], -1.0],
	["Chest", 1180, -400, ["frag", "health_pack"], 30.0],
	["ShelfLeftHigh", 170, -720, ["battery_pack", "health_pack"], -1.0],
	["ShelfRightHigh", 2410, -720, ["smg", "assault_rifle"], -1.0],
]

## name, position, team, kind
const BASES := [
	["BaseTeam0", Vector2(120, 0), 0, "flag"],
	["BaseTeam1", Vector2(2440, 0), 1, "flag"],
]

var _solids: Array[PackedVector2Array] = []


func _init() -> void:
	var kit := ArtLibrary.kit()
	var root := GameMap.new()
	root.name = "Bedroom"
	root.display_name = "Bedroom"
	root.bounds = Rect2(0, -CEILING, ROOM, CEILING + FLOOR_DEPTH)

	# Backdrop: wallpaper, window and posters on a slower layer, skirting on the floor line.
	var back := Node2D.new()
	back.name = "Backdrop"
	back.z_index = -10
	_add(root, root, back)
	var wall := Parallax2D.new()
	wall.name = "Wall"
	wall.scroll_scale = WALL_SCROLL
	_add(root, back, wall)
	var paper := KitTiles.new()
	paper.name = "Paper"
	paper.piece = "wall_tile"
	paper.area = Rect2(-400, -CEILING - 300, ROOM + 800, CEILING + 300)
	paper.wash_top = Color(0.16, 0.18, 0.3, 0.22)
	paper.wash_bottom = Color(0.98, 0.86, 0.66, 0.1)
	_add(root, wall, paper)
	for b: Array in BACK:
		var p := KitProp.new()
		p.name = String(b[0]).capitalize().replace(" ", "") + str(wall.get_child_count())
		p.piece = b[0]
		p.cast_shadow = false
		var want: Vector2 = b[1]
		# Seen from a camera centred on the piece, it lands where it is written.
		p.position = want - want * (Vector2.ONE - WALL_SCROLL)
		_add(root, wall, p)
	var skirting := KitTiles.new()
	skirting.name = "Skirting"
	skirting.piece = "skirting"
	skirting.along_x = true
	skirting.area = Rect2(-64, -40, ROOM + 128, 40)
	_add(root, back, skirting)

	var light := KitProp.new()
	light.name = "LampLight"
	light.piece = "desk_lamp_glow"
	light.cast_shadow = false
	light.z_index = 5
	light.position = Vector2(1560, 0) + (Vector2(970, 420) - Vector2(60, 3160)) * PX

	# Props and their collision.
	var props := Node2D.new()
	props.name = "Props"
	_add(root, root, props)
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	terrain.draw_shapes = false
	_add(root, root, terrain)
	_rect(root, terrain, "Floor", Rect2(-64, 0, ROOM + 128, 96))
	_rect(root, terrain, "WallLeft", Rect2(-64, -CEILING - 64, 64, CEILING + 160))
	_rect(root, terrain, "WallRight", Rect2(ROOM, -CEILING - 64, 64, CEILING + 160))
	_rect(root, terrain, "Ceiling", Rect2(-64, -CEILING - 64, ROOM + 128, 64))
	var counts := {}
	for e: Array in PROPS:
		var id: String = e[0]
		counts[id] = int(counts.get(id, 0)) + 1
		var p := KitProp.new()
		p.name = id.to_pascal_case() + str(counts[id])
		p.piece = id
		p.flip = e[2]
		p.position = e[1]
		_add(root, props, p)
		var xf := Transform2D(0.0, p.position) * KitProp.image_xf_for(id, p.flip)
		var n := 0
		for c: Dictionary in kit[id].get("collision", []):
			var poly := PackedVector2Array()
			for pt: Array in c.poly:
				poly.append(xf * Vector2(float(pt[0]), float(pt[1])))
			var cp := CollisionPolygon2D.new()
			n += 1
			cp.name = "%s%d" % [p.name, n]
			cp.polygon = poly
			_add(root, terrain, cp)
			_solids.append(poly)
	_add(root, root, light)

	var floor := KitTiles.new()
	floor.name = "FloorBoards"
	floor.piece = "floor"
	floor.along_x = true
	floor.area = Rect2(-64, -12, ROOM + 128, 12)
	_add(root, root, floor)
	_solids.append(PackedVector2Array([Vector2(-64, 0), Vector2(ROOM + 64, 0), Vector2(ROOM + 64, 96), Vector2(-64, 96)]))

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	_add(root, root, spawns)
	for s: Array in SPAWNS:
		var p := SpawnPoint.new()
		p.name = s[0]
		p.position = Vector2(s[1], _surface(s[1], s[2]))
		p.team = -1
		_add(root, spawns, p)

	var pickups := Node2D.new()
	pickups.name = "Pickups"
	_add(root, root, pickups)
	for s: Array in PICKUPS:
		var p := PickupPoint.new()
		p.name = s[0]
		p.position = Vector2(s[1], _surface(s[1], s[2]))
		p.items = PackedStringArray(s[3])
		p.interval = s[4]
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
		DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
		err = ResourceSaver.save(packed, OUT)
	print("saved %s: %s" % [OUT, error_string(err)])
	root.free()
	quit(0 if err == OK else 1)


## The first solid surface below (x, from_y).
func _surface(x: float, from_y: float) -> float:
	var best := INF
	for poly in _solids:
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			if (a.x - x) * (b.x - x) > 0.0 or a.x == b.x:
				continue
			var y := lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
			if y >= from_y and y < best:
				best = y
	if best == INF:
		push_error("no surface under %s, %s" % [x, from_y])
		return 0.0
	return snappedf(best, 0.25)


func _rect(root: Node, parent: Node, n: String, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	cs.name = n
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	_add(root, parent, cs)
	_solids.append(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))


func _add(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root
