class_name SimHudSource
extends HudSource
## Reads one player's HUD numbers from the match: health, battery, the other toys for the radar.
## What the sim does not hold yet comes from `stub` (see `CombatStub`).

var sim: MatchSim
var me_id: int = 0
var stub: CombatStub


func _init(match_sim: MatchSim, toy_id: int, combat: CombatStub = null) -> void:
	sim = match_sim
	me_id = toy_id
	stub = combat if combat != null else CombatStub.new()


func read(into: HudState, dt: float) -> void:
	var me := sim.toy(me_id)
	if me != null:
		into.health = me.health
		into.health_max = sim.rules.max_health
		into.battery = me.battery
		into.battery_max = me.battery_max
		into.my_position = me.position
	into.batteries_included = sim.rules.batteries_included
	into.my_team = stub.team_of(me_id)
	into.contacts.clear()
	for t in sim.toys:
		if t.toy_id == me_id:
			continue
		var c := HudState.Contact.new()
		c.toy_id = t.toy_id
		c.team = stub.team_of(t.toy_id)
		c.position = t.position
		c.velocity = t.velocity
		c.fired = stub.take_fired(t.toy_id)
		c.name = stub.name_of(t.toy_id)
		into.contacts.append(c)
	stub.fill(into, dt)
