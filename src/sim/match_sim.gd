class_name MatchSim
extends Node2D
## The match server's simulation: owns the map, the toys and the tick (rules A1 to A3).
##
## It steps only when told to, one fixed tick at a time, from one `InputIntent` per toy. It
## reads no device input and draws nothing. The app's view and the headless server drive it
## the same way. LAN, online and tests all run this one class.

signal ticked(tick: int)

var rules: Ruleset
var map: GameMap
var tick: int = 0
var toys: Array[SimToy] = []
var env := ToyMotor.Env.new()

var _next_id: int = 1


## Takes a checked ruleset and a map node (not yet in the tree).
func setup(ruleset: Ruleset, map_node: GameMap) -> void:
	rules = ruleset
	map = map_node
	add_child(map)
	refresh_env()


## Call after changing rules (the tuning sandbox does) so the match picks them up.
func refresh_env() -> void:
	env.batteries_included = rules.batteries_included
	env.battery_full = battery_full()


## T-20 and US-02.9: the modifier wins, then the map, then the ruleset.
func battery_full() -> float:
	if rules.battery_size >= 0.0:
		return rules.battery_size
	if map != null and map.battery_full >= 0.0:
		return map.battery_full
	return rules.battery_full


## Spawns a toy at spawn point `index` (wrapping), or at `at` when given (feet position).
func spawn_toy(index: int = 0, toy_type: StringName = &"plastic_soldier", at: Variant = null) -> SimToy:
	var toy := SimToy.new()
	toy.toy_id = _next_id
	_next_id += 1
	toy.name = "Toy%d" % toy.toy_id
	toy.toy_type = toy_type
	toy.build(rules)
	var feet: Vector2
	if at != null:
		feet = at
	else:
		var points := map.spawn_points()
		feet = points[index % points.size()].global_position if not points.is_empty() else Vector2.ZERO
	toy.position = feet + Vector2(0.0, rules.body_bottom - SimToy.SAFE_MARGIN)
	toy.prev_position = toy.position
	toy.battery = env.battery_full
	toy.battery_max = env.battery_full
	add_child(toy)
	toys.append(toy)
	return toy


func toy(toy_id: int) -> SimToy:
	for t in toys:
		if t.toy_id == toy_id:
			return t
	return null


## Runs one tick. `intents` maps toy id to that toy's `InputIntent`; a missing one is idle.
func step(intents: Dictionary = {}) -> void:
	for t in toys:
		t.prev_position = t.position
		var intent: InputIntent = intents.get(t.toy_id, null)
		intent = intent.sanitized() if intent != null else InputIntent.idle()
		ToyMotor.step(t, intent, rules, env, SimClock.TICK)
	tick += 1
	ticked.emit(tick)


## Runs `ticks` ticks with the same intents.
func run(ticks: int, intents: Dictionary = {}) -> void:
	for i in ticks:
		step(intents)
