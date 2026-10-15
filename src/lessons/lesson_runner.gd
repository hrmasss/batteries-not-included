class_name LessonRunner
extends RefCounted
## The first lessons (US-35, a short first set): move, fly, aim and fire, pick up, grenade.
## Each lesson is a few steps; a step names the thing to do and the control to use, and the
## lesson moves on only when the player has done it (US-35.2). It reads the match and the
## player's intents; targets and items it needs come in through the match like any toy's.

const LESSONS: Array[StringName] = [&"move", &"fly", &"aim_fire", &"pick_up", &"grenade"]
const TITLES := {
	&"move": "Move", &"fly": "Jump and fly", &"aim_fire": "Aim and fire",
	&"pick_up": "Pick up and swap", &"grenade": "Grenades",
}

## Controls a step can point at, named like the touch layout's.
const MOVE_STICK := &"move_stick"
const AIM_STICK := &"aim_stick"
const PICK_UP := &"pick_up"
const SWITCH := &"switch"
const GRENADE := &"grenade"

## What each lesson asks for. Lesson pacing, not match rules.
const WALK_DISTANCE := 300.0
const FLY_FIRST := 1.0
const FLY_MORE := 3.0
const AIM_TIME := 1.0
const TARGET_DISTANCE := 220.0
const ITEM_DISTANCE := 110.0
const GRENADE_TARGET_DISTANCE := 320.0
const GUN := &"smg"
## Placing things beside the player: shares of the asked distance tried, nearest to the ask
## first, how far above the player's feet a floor may be, the step along a floor and the
## height change that still counts as the same floor. Solver detail, not lesson pacing.
const TRIES: Array[float] = [1.0, 0.85, 1.15, 0.7, 1.3, 0.55, 0.4]
const RISE := 60.0
const PROBE := 8.0
const LEDGE := 6.0
## How far a start spot's open floor is measured on each side, u, and the open air it needs
## above the head (the fly lesson takes off from it).
const ROOM_REACH := 400.0
const HEADROOM := 200.0

signal advanced(step: int)
signal finished(id: StringName)

class Step:
	extends RefCounted
	var text: String
	## Desktop hint.
	var keys: String
	var control: StringName
	var check: Callable

	func _init(t: String, k: String, c: StringName, done: Callable) -> void:
		text = t
		keys = k
		control = c
		check = done


var sim: MatchSim
var combat: CombatSim
var me: Fighter
## func(team: int, feet: Vector2) -> Fighter: a still target the view can draw.
var spawn_target: Callable
var id: StringName = &""
var steps: Array[Step] = []
var index: int = 0
var done: bool = false
var target: Fighter = null

# What the player has done since the step began.
var _walked: float = 0.0
var _aimed: float = 0.0
var _flight_at_step: float = 0.0
var _battery_low: float = 0.0
var _events: Array[Dictionary] = []
var _last_x: float = 0.0
var _gun_placed: bool = false


func _init(match_sim: MatchSim, fighter: Fighter, spawner: Callable) -> void:
	sim = match_sim
	combat = match_sim.combat
	me = fighter
	spawn_target = spawner


static func next_of(lesson: StringName) -> StringName:
	var i := LESSONS.find(lesson)
	return LESSONS[i + 1] if i >= 0 and i + 1 < LESSONS.size() else &""


func start(lesson: StringName) -> void:
	id = lesson
	index = 0
	done = false
	steps = _steps(lesson)
	_begin_step()


func step() -> Step:
	return steps[index] if index < steps.size() else null


## Call after every tick with the player's intent for that tick.
func on_tick(intent: InputIntent) -> void:
	if done:
		return
	var t := me.toy
	if t.foot_contact and t.active:
		_walked += absf(t.position.x - _last_x)
	_last_x = t.position.x
	if intent.aim != Vector2.ZERO:
		_aimed += SimClock.TICK
	_battery_low = minf(_battery_low, t.battery)
	_events.append_array(combat.events)
	if steps[index].check.call():
		index += 1
		if index >= steps.size():
			done = true
			finished.emit(id)
			return
		_begin_step()
		advanced.emit(index)


func _begin_step() -> void:
	_walked = 0.0
	_aimed = 0.0
	_flight_at_step = me.toy.flight_time
	_battery_low = me.toy.battery
	_events.clear()
	_last_x = me.toy.position.x


func _saw(type: StringName, extra: Callable = Callable()) -> bool:
	for e in _events:
		if e.type == type and (not extra.is_valid() or extra.call(e)):
			return true
	return false


func _mine(e: Dictionary) -> bool:
	return e.get("toy", 0) == me.id()


## Feet on a floor about `distance` to one side of the player, where a toy fits: on the
## player's own floor with nothing in the way when `walk` (an item to walk to), else anywhere
## in the player's sight (a target). Art maps are cluttered: the bed's post, the space under it.
func _beside(distance: float, walk: bool = false) -> Vector2:
	var p := me.toy.position
	var b := sim.map.bounds
	var first := 1.0 if b.end.x - p.x > p.x - b.position.x else -1.0
	var my_feet := _feet(p)
	for k in TRIES:
		for side: float in [first, -first]:
			var found: Variant = _floor_at(p.x + side * distance * k, p.y)
			if found == null:
				continue
			var feet: Vector2 = found
			if walk and (absf(feet.y - my_feet.y) > LEDGE or not _walkable(p.x, feet.x, my_feet.y)):
				continue
			if not walk and not _in_sight(p, _origin(feet)):
				continue
			return feet
	return _feet(p + Vector2(first * distance, 0.0))


## Feet on the first floor below (x, a little above `y`) where a toy fits, or null.
func _floor_at(x: float, y: float) -> Variant:
	var from := Vector2(x, y - RISE)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, RISE + TARGET_DISTANCE), 1 << (SimToy.TERRAIN_LAYER - 1))
	var hit := sim.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector2).y > SimToy.FLOOR_NORMAL_Y:
		return null
	var feet: Vector2 = hit.position
	return feet if _fits(_origin(feet)) else null


## True when a standing toy at `origin` touches no terrain.
func _fits(origin: Vector2) -> bool:
	var rules := sim.rules
	var top := rules.head_height + rules.head_radius
	var box := RectangleShape2D.new()
	box.size = Vector2(rules.body_width, top - rules.body_bottom - SimToy.SAFE_MARGIN * 4.0)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = box
	q.collision_mask = 1 << (SimToy.TERRAIN_LAYER - 1)
	q.transform = Transform2D(0.0, origin + Vector2(0.0, -(top + rules.body_bottom) * 0.5))
	return sim.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


## True when floor runs at `floor_y` from x `a` to x `b` with room for a toy all the way.
func _walkable(a: float, b: float, floor_y: float) -> bool:
	var dir := signf(b - a)
	var x := a
	while absf(b - x) > PROBE:
		x += dir * PROBE
		var found: Variant = _floor_at(x, floor_y)
		if found == null or absf((found as Vector2).y - floor_y) > LEDGE:
			return false
	return true


## How far a toy standing at `origin` can walk on its floor to one side, up to ROOM_REACH.
func room_at(origin: Vector2, side: float) -> float:
	var floor_y := _feet(origin).y
	var d := 0.0
	while d < ROOM_REACH:
		var found: Variant = _floor_at(origin.x + side * (d + PROBE), floor_y)
		if found == null or absf((found as Vector2).y - floor_y) > LEDGE:
			break
		d += PROBE
	return d


func _in_sight(from: Vector2, to: Vector2) -> bool:
	var eye := Vector2(0.0, -sim.rules.head_height)
	var q := PhysicsRayQueryParameters2D.create(from + eye, to + eye, 1 << (SimToy.TERRAIN_LAYER - 1))
	return sim.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _feet(origin: Vector2) -> Vector2:
	return origin - Vector2(0.0, sim.rules.body_bottom - SimToy.SAFE_MARGIN)


func _origin(feet: Vector2) -> Vector2:
	return feet + Vector2(0.0, sim.rules.body_bottom - SimToy.SAFE_MARGIN)


## The map's spawn point with the most open floor around it, for a lesson to start on: the
## lessons walk, and place an item and targets beside the player. Room on the tighter side
## counts double, so the player is not pinned against a wall.
func best_start() -> int:
	var best := 0
	var best_room := -1.0
	var points := sim.map.spawn_points()
	for i in points.size():
		var o := _origin(points[i].global_position)
		var head := o + Vector2(0.0, -sim.rules.head_height - sim.rules.head_radius)
		if not _in_sight(head, head + Vector2(0.0, -HEADROOM)):
			continue
		var left := room_at(o, -1.0)
		var right := room_at(o, 1.0)
		var room := minf(left, right) * 2.0 + maxf(left, right)
		if room > best_room:
			best_room = room
			best = i
	return best


## A still target beside the player, once; a popped one respawns by the match's own rules.
func _target_at(distance: float) -> void:
	if target != null:
		return
	target = spawn_target.call(me.team + 1, _beside(distance))


func _steps(lesson: StringName) -> Array[Step]:
	var s: Array[Step] = []
	match lesson:
		&"move":
			s.append(Step.new("Walk: slide the left stick left and right.", "A and D to walk", MOVE_STICK,
				func() -> bool: return _walked >= WALK_DISTANCE))
			s.append(Step.new("Jump: push the left stick up.", "W or Space to jump", MOVE_STICK,
				func() -> bool: return _saw_jump()))
			s.append(Step.new("Crouch: pull the left stick down.", "S to crouch", MOVE_STICK,
				func() -> bool: return me.toy.crouched))
		&"fly":
			s.append(Step.new("Jump and keep pushing up: the jetpack takes over.", "Hold W", MOVE_STICK,
				func() -> bool: return me.toy.flight_time - _flight_at_step >= FLY_FIRST))
			s.append(Step.new("Fly anywhere: the stick points the way. Up drains the battery fastest.", "WASD to fly", MOVE_STICK,
				func() -> bool: return me.toy.flight_time - _flight_at_step >= FLY_MORE))
			s.append(Step.new("Let go to land. The battery refills a moment after you stop.", "Let go of the keys", MOVE_STICK,
				func() -> bool: return me.toy.foot_contact and me.toy.battery > _battery_low + sim.rules.refill_rate * FLY_FIRST))
		&"aim_fire":
			s.append(Step.new("Aim with the right stick.", "Move the mouse to aim", AIM_STICK,
				func() -> bool: return _aimed >= AIM_TIME))
			s.append(Step.new("Push the aim stick to its edge to fire. Pop the target!", "Left mouse button fires", AIM_STICK,
				func() -> bool:
					_target_at(TARGET_DISTANCE)
					return _saw(&"pop", func(e: Dictionary) -> bool: return e.toy == target.id() and e.killer == me.id())))
		&"pick_up":
			s.append(Step.new("A gun lies on the floor. Walk to it.", "A and D to walk", MOVE_STICK,
				func() -> bool:
					_place_gun()
					return me.offer >= 0))
			s.append(Step.new("Tap Pick up to take it.", "E picks up", PICK_UP,
				func() -> bool: return _saw(&"pickup", func(e: Dictionary) -> bool: return _mine(e) and e.item == GUN)))
			s.append(Step.new("Tap the gun display to swap between your two guns.", "Q swaps guns", SWITCH,
				func() -> bool: return _saw(&"switch", _mine)))
		&"grenade":
			s.append(Step.new("Tap the grenade button: a frag flies where you aim.", "G throws a frag", GRENADE,
				func() -> bool:
					_target_at(GRENADE_TARGET_DISTANCE)
					_restock()
					return _saw(&"throw", _mine)))
			s.append(Step.new("Frags bounce and roll, then blast. Catch the target in one!", "Aim, then G", GRENADE,
				func() -> bool:
					_target_at(GRENADE_TARGET_DISTANCE)
					_restock()
					return _saw(&"hit", func(e: Dictionary) -> bool: return e.toy == target.id() and e.attacker == me.id() and e.kind == CombatSim.Hurt.BLAST)))
	return s


func _saw_jump() -> bool:
	return not me.toy.foot_contact and me.toy.since_jump < SimClock.TICK * 2.0


func _place_gun() -> void:
	if _gun_placed:
		return
	_gun_placed = true
	combat.place_item(GUN, _origin(_beside(ITEM_DISTANCE, true)))


## Out of frags: a frag pickup lands at the player's feet, as one from the map would.
func _restock() -> void:
	if me.grenade_count() > 0:
		return
	for it in combat.items:
		if WeaponTable.GRENADES.has(it.item):
			return
	combat.place_item(&"frag", me.toy.position)
