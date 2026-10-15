class_name TestWorld
extends RefCounted
## Builds small maps and matches in code for tests.

const FLOOR_Y := 1000.0


## A map with a floor at FLOOR_Y spanning `width`, walls at both ends, `rects` as extra terrain
## (Rect2s, y down), and one spawn point at `spawn` (feet).
static func map(width: float = 4000.0, rects: Array = [], spawn: Vector2 = Vector2(400, FLOOR_Y)) -> GameMap:
	var m := GameMap.new()
	m.name = "TestMap"
	m.bounds = Rect2(0, -6000, width, FLOOR_Y + 6200)
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	terrain.draw_shapes = false
	var all: Array = [Rect2(-200, FLOOR_Y, width + 400, 200), Rect2(-200, -6000, 200, FLOOR_Y + 6000), Rect2(width, -6000, 200, FLOOR_Y + 6000)]
	all.append_array(rects)
	for r: Rect2 in all:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		terrain.add_child(cs)
	m.add_child(terrain)
	var spawns := Node2D.new()
	spawns.name = "Spawns"
	var sp := SpawnPoint.new()
	sp.position = spawn
	spawns.add_child(sp)
	m.add_child(spawns)
	return m


static func rules() -> Ruleset:
	var res := RulesetLoader.load_standard()
	assert(res.ok(), "standard ruleset: %s" % ", ".join(res.errors))
	return res.ruleset


## A match on `m` (default: TestWorld.map()) with `r` (default: standard), added under `parent`.
static func sim(parent: Node, r: Ruleset = null, m: GameMap = null) -> MatchSim:
	var s := MatchSim.new()
	s.setup(r if r != null else rules(), m if m != null else map())
	parent.add_child(s)
	return s
