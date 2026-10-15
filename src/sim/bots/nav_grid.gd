class_name NavGrid
extends RefCounted
## Where a toy can go on a map, as a grid for bots: free cells, cells with a floor to stand
## on, and paths between them. Built once per match from the map's terrain with physics
## queries; paths come from Godot's `AStarGrid2D`. Walking is cheaper than flying, so paths
## hug floors and take to the air where they must (the battery is finite, T-20).
##
## World space, y down, like `SimToy`. A path point is where a toy's body origin goes: on a
## floor cell, standing on that floor; in the air, the cell's centre.

## Slack added to the toy's width and to the floor search. Solver detail, not tuning.
const MARGIN := 4.0
## Path points ahead a bot checks for a straight line. Solver detail, not tuning.
const LOOK_AHEAD := 8
## How far to look around a blocked cell for a free one, in cells. Solver detail.
const SNAP_RADIUS := 3
## Shorter than this, a line has no length. Solver detail.
const EPSILON := 1e-6

var cell: float
var origin: Vector2
var size: Vector2i
var astar := AStarGrid2D.new()
## Per cell, by index y * size.x + x: the standing body origin's y for floor cells, NAN for air.
var stand_y: PackedFloat32Array = []
var free_cells: Array[Vector2i] = []
var floor_cells: Array[Vector2i] = []

var _space: PhysicsDirectSpaceState2D
var _half_width: float
## The toy's whole height, feet (less MARGIN) to the top of the head, swept by `clear`.
var _sweep := PhysicsShapeQueryParameters2D.new()
var _sweep_offset: Vector2


## Builds the grid for `sim`'s map. `cell_size` and `air_cost` come from the bot skill table.
static func build(sim: MatchSim, cell_size: float, air_cost: float) -> NavGrid:
	var g := NavGrid.new()
	g._make(sim, cell_size, air_cost)
	return g


func _make(sim: MatchSim, cell_size: float, air_cost: float) -> void:
	var rules := sim.rules
	cell = cell_size
	var b := sim.map.bounds
	origin = b.position
	size = Vector2i(ceili(b.size.x / cell), ceili(b.size.y / cell))
	_space = sim.get_world_2d().direct_space_state
	_half_width = rules.body_width * 0.5
	# World y down: the feet are -body_bottom below the origin, the head's top above it.
	var feet := -rules.body_bottom - MARGIN
	var head := -(rules.head_height + rules.head_radius)
	var tall := RectangleShape2D.new()
	tall.size = Vector2(rules.body_width, feet - head)
	_sweep.shape = tall
	_sweep.collision_mask = 1 << (SimToy.TERRAIN_LAYER - 1)
	_sweep.collide_with_areas = false
	_sweep_offset = Vector2(0.0, (feet + head) * 0.5)
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = Vector2(cell, cell)
	astar.offset = origin + Vector2(cell, cell) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.update()
	stand_y.resize(size.x * size.y)
	# A free cell has room for the toy's middle: its width by its width, at the centre.
	var box := RectangleShape2D.new()
	box.size = Vector2(rules.body_width + MARGIN, rules.body_width + MARGIN)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = box
	q.collision_mask = 1 << (SimToy.TERRAIN_LAYER - 1)
	q.collide_with_areas = false
	# The free cell just above a surface has its centre up to a box half plus a cell above it,
	# wherever the surface falls in the grid (the art maps' props are not on the grid).
	var floor_reach := box.size.y * 0.5 + cell + MARGIN
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			var at := center(c)
			q.transform = Transform2D(0.0, at)
			stand_y[index(c)] = NAN
			if not _space.intersect_shape(q, 1).is_empty():
				astar.set_point_solid(c, true)
				continue
			free_cells.append(c)
			var hit := _ray(at, at + Vector2(0.0, floor_reach))
			if not hit.is_empty() and (hit.normal as Vector2).y < SimToy.FLOOR_NORMAL_Y:
				stand_y[index(c)] = (hit.position as Vector2).y + rules.body_bottom - SimToy.SAFE_MARGIN
				floor_cells.append(c)
			else:
				astar.set_point_weight_scale(c, 1.0 + air_cost)


func index(c: Vector2i) -> int:
	return c.y * size.x + c.x


func center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell), floori((p.y - origin.y) / cell))


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func is_free(c: Vector2i) -> bool:
	return in_grid(c) and not astar.is_point_solid(c)


func is_floor(c: Vector2i) -> bool:
	return in_grid(c) and not is_nan(stand_y[index(c)])


## Where a toy's body origin goes in cell `c`.
func point(c: Vector2i) -> Vector2:
	var p := center(c)
	if is_floor(c):
		p.y = stand_y[index(c)]
	return p


## The free cell nearest to `p`, or (-1, -1) if none is close.
func free_near(p: Vector2) -> Vector2i:
	var c := cell_of(p)
	if is_free(c):
		return c
	var best := Vector2i(-1, -1)
	var best_d := INF
	for r in range(1, SNAP_RADIUS + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if is_free(n):
					var d := center(n).distance_squared_to(p)
					if d < best_d:
						best_d = d
						best = n
		if best.x >= 0:
			return best
	return best


## Path points from `from` to `to`, both world positions; empty if there is no way.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := free_near(from)
	var b := free_near(to)
	var out := PackedVector2Array()
	if a.x < 0 or b.x < 0:
		return out
	for c: Vector2i in astar.get_id_path(a, b):
		out.append(point(c))
	return out


## A free floor point picked by `rng`, for wandering.
func random_floor(rng: RandomNumberGenerator) -> Vector2:
	var pool := floor_cells if not floor_cells.is_empty() else free_cells
	if pool.is_empty():
		return origin
	return point(pool[rng.randi_range(0, pool.size() - 1)])


## True when a toy's whole body, feet to head, moves from `a` to `b` (body origins) and
## touches no terrain. A line as wide as the toy is not enough: under the bed the gap is
## barely taller than a toy, and a line through its middle misses the rail its head hits.
func clear(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	if d.length_squared() < EPSILON:
		return true
	_sweep.transform = Transform2D(0.0, a + _sweep_offset)
	_sweep.motion = d
	var hit := _space.cast_motion(_sweep)
	return hit.is_empty() or hit[0] >= 1.0


## True when nothing solid lies on the thin line from `a` to `b` (sight).
func sees(a: Vector2, b: Vector2) -> bool:
	return _ray(a, b).is_empty()


func _ray(a: Vector2, b: Vector2) -> Dictionary:
	if a.is_equal_approx(b):
		return {}
	var q := PhysicsRayQueryParameters2D.create(a, b, 1 << (SimToy.TERRAIN_LAYER - 1))
	q.collide_with_areas = false
	q.hit_from_inside = true
	return _space.intersect_ray(q)
