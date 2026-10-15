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
const GRENADE_TARGET_DISTANCE := 200.0
const GUN := &"smg"

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


## A point on the floor `distance` to the side of the player with the most room.
func _beside(distance: float) -> Vector2:
	var p := me.toy.position
	var b := sim.map.bounds
	var side := 1.0 if b.end.x - p.x > p.x - b.position.x else -1.0
	var at := p + Vector2(side * distance, 0.0)
	var q := PhysicsRayQueryParameters2D.create(at, at + Vector2(0, TARGET_DISTANCE), 1 << (SimToy.TERRAIN_LAYER - 1))
	var hit := sim.get_world_2d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else at - Vector2(0, sim.rules.body_bottom)


func _target_at(distance: float) -> void:
	if target != null and target.alive:
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
			s.append(Step.new("Frags bounce, then blast. Catch the target in one!", "Aim, then G", GRENADE,
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
	combat.place_item(GUN, _beside(ITEM_DISTANCE) + Vector2(0, sim.rules.body_bottom))


## Out of frags: a frag pickup lands at the player's feet, as one from the map would.
func _restock() -> void:
	if me.grenade_count() > 0:
		return
	for it in combat.items:
		if WeaponTable.GRENADES.has(it.item):
			return
	combat.place_item(&"frag", me.toy.position)
