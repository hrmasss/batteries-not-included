extends CombatTest
## US-14 health that comes back; US-15.2 kill credit. Sim checks.


# US-14.1: full health on spawn.
func test_us14_1_full_health_on_spawn() -> void:
	make()
	var me := combat.spawn()
	assert_eq(me.toy.health, rules.max_health)


# US-14.2: regen at the regen rate, with no delay after damage.
func test_us14_2_regen_no_delay() -> void:
	make()
	var me := add(400)
	var you := add(600)
	combat.hurt(you, 40.0, me.id(), &"pistol", CombatSim.Hurt.BULLET)
	var after_hit := you.toy.health
	run(1.0)
	assert_almost_eq(you.toy.health - after_hit, rules.regen_rate * 1.0, 0.05, "regen from the first tick")
	combat.hurt(you, 5.0, me.id(), &"pistol", CombatSim.Hurt.BULLET)
	var h := you.toy.health
	step()
	assert_almost_eq(you.toy.health - h, rules.regen_rate * TICK, 0.0001, "no pause after a hit")


func test_us14_2_regen_stops_at_full() -> void:
	make()
	var me := add(400)
	run(1.0)
	assert_eq(me.toy.health, rules.max_health)


# US-14.3: a pack heals as T-32 says; a full toy leaves it.
func test_us14_3_health_pack() -> void:
	make()
	var me := add(400)
	var you := add(800)
	combat.hurt(you, 95.0, me.id(), &"pistol", CombatSim.Hurt.BULLET)
	var h := you.toy.health
	combat.place_item(CombatSim.HEALTH_PACK, you.toy.position)
	step()
	assert_almost_eq(you.toy.health - h, rules.pack_instant + rules.regen_rate * TICK, 0.01, "the instant part first")
	step()
	assert_gt(you.toy.health - h, rules.pack_instant + rules.pack_flow_rate * TICK * 0.9, "then the flow")
	var need := rules.pack_flow / rules.pack_flow_rate
	run(need + 0.05)
	assert_eq(you.toy.health, rules.max_health, "full after about a second")
	assert_eq(combat.items.size(), 0, "pack used")


func test_us14_3_full_toy_leaves_the_pack() -> void:
	make()
	var me := add(400)
	combat.place_item(CombatSim.HEALTH_PACK, me.toy.position)
	run(0.2)
	assert_eq(combat.items.size(), 1, "left on the floor")


# US-14.4: a battery pack holds the battery full for its time (T-24).
func test_us14_4_battery_pack() -> void:
	make()
	var me := add(400)
	combat.place_item(CombatSim.BATTERY_PACK, me.toy.position)
	step()
	assert_eq(combat.items.size(), 0, "taken")
	me.toy.battery = 0.0
	step()
	assert_eq(me.toy.battery, me.toy.battery_max, "held full")
	run(rules.battery_pack_time)
	me.toy.battery = 0.0
	step()
	assert_lt(me.toy.battery, me.toy.battery_max, "wears off after its time")


# US-14.5: outside the map's bounds, out-of-bounds damage every interval.
func test_us14_5_out_of_bounds_hurts() -> void:
	make()
	var me := add(400)
	me.toy.position = Vector2(400, sim.map.bounds.position.y - 100)
	var h := me.toy.health
	# Hold it outside: the test map's bounds are drawn wide of the walls.
	for k in ticks(1.0):
		me.toy.position = Vector2(400, sim.map.bounds.position.y - 100)
		me.toy.velocity = Vector2.ZERO
		step()
	var expect := rules.out_of_bounds_damage / rules.out_of_bounds_interval - rules.regen_rate
	assert_almost_eq(h - me.toy.health, expect, rules.out_of_bounds_damage, "about 50 HP per second")


# US-15.2: the kill goes to the last hit's attacker; no assists.
func test_us15_2_last_hit_gets_the_kill() -> void:
	make()
	var a := add(300)
	var b := add(400)
	var you := add(600)
	combat.hurt(you, 60.0, a.id(), &"pistol", CombatSim.Hurt.BULLET)
	combat.hurt(you, 60.0, b.id(), &"smg", CombatSim.Hurt.BULLET)
	assert_false(you.alive)
	assert_eq([a.kills, b.kills], [0, 1], "the last hit, no assist")
	assert_eq(you.deaths, 1)
	assert_eq([you.popped_by, you.popped_with], [b.id(), &"smg"], "who and with what, for the respawn screen")


func test_us15_2_no_attacker_credits_the_last_damager() -> void:
	make()
	var a := add(300)
	var you := add(600)
	combat.hurt(you, 90.0, a.id(), &"pistol", CombatSim.Hurt.BULLET)
	for k in ticks(1.0):
		if not you.alive:
			break
		you.toy.position = Vector2(400, sim.map.bounds.position.y - 100)
		step()
	assert_false(you.alive, "popped out of bounds")
	assert_eq(a.kills, 1, "the last toy that hurt it")
	assert_eq(you.suicides, 0)


func test_pop_takes_the_toy_out() -> void:
	make()
	var me := add(400)
	var you := add(500)
	combat.hurt(you, rules.max_health, me.id(), &"pistol", CombatSim.Hurt.BULLET)
	assert_false(you.toy.active, "a popped toy is out of play")
	weapon(&"pistol").spread = 0.0
	set_intent(me, AIM_RIGHT, true)
	assert_eq(collect(&"hit", 0.5).size(), 0, "bullets pass where it was")
	assert_eq(events_of(&"pop").size(), 0)
