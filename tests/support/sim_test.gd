class_name SimTest
extends GutTest
## Base for movement tests: a fresh match on a test map with one settled toy.

const TICK := SimClock.TICK
const UP := Vector2(0, 1)
const DOWN := Vector2(0, -1)
const RIGHT := Vector2(1, 0)
const LEFT := Vector2(-1, 0)

var sim: MatchSim
var toy: SimToy
var rules: Ruleset


func make(r: Ruleset = null, m: GameMap = null, settle: bool = true) -> SimToy:
	rules = r if r != null else TestWorld.rules()
	# One match at a time: two maps in one physics space would touch each other's toys.
	if sim != null and is_instance_valid(sim):
		sim.free()
	sim = TestWorld.sim(self, rules, m)
	toy = sim.spawn_toy(0)
	if settle:
		Drills.settle(sim, toy)
	return toy


func after_each() -> void:
	if sim != null and is_instance_valid(sim):
		sim.free()
	sim = null


func ticks(seconds: float) -> int:
	return roundi(seconds / TICK)


func hold(stick: Vector2, seconds: float, held: bool = true) -> void:
	sim.run(ticks(seconds), {toy.toy_id: InputIntent.make(stick, held)})


func step_with(stick: Vector2, held: bool = true) -> void:
	sim.step({toy.toy_id: InputIntent.make(stick, held)})


func idle(seconds: float) -> void:
	sim.run(ticks(seconds))


## Feet height above the test floor, u.
func height() -> float:
	return TestWorld.FLOOR_Y - (toy.position.y - rules.body_bottom)


## Velocity in stick space (y up).
func vel() -> Vector2:
	return Vector2(toy.velocity.x, -toy.velocity.y)


## Takes off: jump and hold up until the jetpack engages. Fails the test if it never does.
func take_off() -> void:
	for i in ticks(2.0):
		step_with(UP)
		if toy.jetpack_on:
			return
	fail_test("jetpack never engaged")
