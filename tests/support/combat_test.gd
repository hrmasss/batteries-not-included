class_name CombatTest
extends GutTest
## Base for combat tests: a match on a flat test map with fighting on, and helpers to drive
## fighters with intents. Every expected number is read from the ruleset.

const TICK := SimClock.TICK
## Aim directions, y up like the sticks.
const AIM_RIGHT := Vector2(1, 0)
const AIM_LEFT := Vector2(-1, 0)
const AIM_UP := Vector2(0, 1)
const AIM_DOWN := Vector2(0, -1)
const FLOOR := TestWorld.FLOOR_Y

var sim: MatchSim
var combat: CombatSim
var rules: Ruleset
## Intent per fighter, held until changed.
var intents: Dictionary = {}


## A match on a 4000 u floor with `rects` as extra terrain. `tune` may change the rules first.
func make(rects: Array = [], tune: Callable = Callable(), m: GameMap = null) -> void:
	# Two matches in one test would share one physics world; take the last one out.
	if sim != null and is_instance_valid(sim) and sim.get_parent() != null:
		sim.get_parent().remove_child(sim)
	rules = TestWorld.rules()
	if tune.is_valid():
		tune.call(rules)
	sim = TestWorld.sim(self, rules, m if m != null else TestWorld.map(4000.0, rects))
	autofree(sim)
	combat = sim.start_combat(7)
	intents = {}


## A fighter with its feet at (x, y), settled, unprotected unless asked.
func add(x: float, team: int = Fighter.NO_TEAM, protect: bool = false, y: float = FLOOR) -> Fighter:
	var t := sim.spawn_toy(0, &"plastic_soldier", Vector2(x, y))
	var f := combat.join(t, team, protect)
	set_intent(f)
	return f


func set_intent(f: Fighter, aim: Vector2 = AIM_RIGHT, fire: bool = false, buttons: int = 0, move: Vector2 = Vector2.ZERO) -> InputIntent:
	var i := InputIntent.make(move, move != Vector2.ZERO, aim)
	i.fire = fire
	i.buttons = buttons
	intents[f.id()] = i
	return i


## Presses `button` for one tick, then lets go.
func press(f: Fighter, button: InputIntent.Act) -> void:
	var i: InputIntent = intents[f.id()]
	i.set_button(button, true)
	step()
	i.set_button(button, false)
	step()


func step() -> void:
	sim.step(_copies())


func run(seconds: float) -> void:
	for k in ticks(seconds):
		step()


func ticks(seconds: float) -> int:
	return roundi(seconds / TICK)


## Runs until `pred` holds or `seconds` pass. Returns whether it held.
func run_until(pred: Callable, seconds: float) -> bool:
	for k in ticks(seconds):
		step()
		if pred.call():
			return true
	return false


## Steps and collects every event of `type` on the way.
func collect(type: StringName, seconds: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in ticks(seconds):
		step()
		for e in combat.events:
			if e.type == type:
				out.append(e)
	return out


func events_of(type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in combat.events:
		if e.type == type:
			out.append(e)
	return out


## Gives `f` a fresh weapon `id` in the main hand, replacing what it holds.
func arm(f: Fighter, id: StringName, second: StringName = &"") -> void:
	f.weapons.clear()
	f.weapons.append(WeaponItem.fresh(rules.weapons.get_def(id)))
	if second != &"":
		f.weapons.append(WeaponItem.fresh(rules.weapons.get_def(second)))
	f.held = 0


func weapon(id: StringName) -> WeaponDef:
	return rules.weapons.get_def(id)


func _copies() -> Dictionary:
	var out := {}
	for k: int in intents:
		out[k] = (intents[k] as InputIntent).copy()
	return out
