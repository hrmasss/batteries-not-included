extends CombatTest
## US-16 pickups; US-22 spawning and protection. Sim checks.


## A test map with pickup points: each entry is [position, items, interval].
func _map_with_points(points: Array, spawns: Array = []) -> GameMap:
	var m := TestWorld.map()
	var holder := Node2D.new()
	holder.name = "Pickups"
	for p: Array in points:
		var pp := PickupPoint.new()
		pp.position = p[0]
		pp.items = PackedStringArray(p[1])
		pp.interval = p[2]
		holder.add_child(pp)
	m.add_child(holder)
	if not spawns.is_empty():
		var sp_holder := m.get_node("Spawns")
		for c in sp_holder.get_children():
			sp_holder.remove_child(c)
			c.free()
		for s: Array in spawns:
			var sp := SpawnPoint.new()
			sp.position = s[0]
			sp.team = s[1]
			sp_holder.add_child(sp)
	return m


# US-16.1: a due point spawns one item drawn at random from its list.
func test_us16_1_point_spawns_from_its_list() -> void:
	var seen := {}
	for seed_try in 6:
		make(Array(), Callable(), _map_with_points([[Vector2(1000, FLOOR), ["smg", "uzi", "health_pack"], -1.0]]))
		combat.rng.seed = seed_try
		step()
		assert_eq(combat.items.size(), 1, "one item")
		seen[combat.items[0].item] = true
	for k: StringName in seen:
		assert_true([&"smg", &"uzi", &"health_pack"].has(k))
	assert_gt(seen.size(), 1, "drawn at random")


# US-16.2: points respawn on the ruleset's interval, or their own.
func test_us16_2_intervals() -> void:
	make(Array(), func(r: Ruleset) -> void: r.pickup_interval = 2.0,
		_map_with_points([[Vector2(1000, FLOOR), ["smg"], -1.0], [Vector2(2000, FLOOR), ["uzi"], 1.0]]))
	var spawned := {&"smg": 0, &"uzi": 0}
	for e in collect(&"item_spawn", 4.05):
		spawned[e.item] += 1
	assert_eq(spawned[&"smg"], 3, "ruleset interval: at 0, 2, 4 s")
	assert_eq(spawned[&"uzi"], 5, "own interval: at 0, 1, 2, 3, 4 s")


# US-16.3: pickups off spawns nothing.
func test_us16_3_pickups_off() -> void:
	make(Array(), func(r: Ruleset) -> void: r.pickup_interval = 0.0,
		_map_with_points([[Vector2(1000, FLOOR), ["smg"], 1.0]]))
	run(3.0)
	assert_eq(combat.items.size(), 0)


# US-16.4: an item fades for the last seconds of its lifetime, then goes.
func test_us16_4_floor_lifetime_and_fade() -> void:
	make()
	var it := combat.place_item(&"smg", Vector2(1000, FLOOR - 2), 20.0)
	run(20.0 - rules.floor_fade - 0.5)
	assert_eq(combat.item_alpha(it), 1.0, "solid before the fade")
	run(rules.floor_fade * 0.5 + 0.5)
	assert_between(combat.item_alpha(it), 0.4, 0.6, "half faded")
	run(rules.floor_fade * 0.5 + 0.1)
	assert_eq(combat.items.size(), 0, "gone")


func test_us16_4_map_item_lasts_interval_less_lead() -> void:
	make(Array(), func(r: Ruleset) -> void: r.pickup_interval = 30.0,
		_map_with_points([[Vector2(1000, FLOOR), ["smg"], -1.0]]))
	step()
	var it: CombatSim.FloorItem = combat.items[0]
	assert_almost_eq(it.lifetime, 30.0 - rules.floor_lifetime_lead, 0.001)


func test_us16_4_empty_dropped_gun_lasts_its_own_time() -> void:
	make()
	var me := add(400)
	var you := add(600)
	arm(you, &"smg")
	you.main_weapon().mag = 0
	you.main_weapon().reserve = 0
	combat.hurt(you, rules.max_health, me.id(), &"pistol", CombatSim.Hurt.BULLET)
	assert_eq(combat.items[0].lifetime, rules.empty_gun_lifetime)


# US-16.5: past the crowding threshold, lifetimes shrink.
func test_us16_5_crowding_shortens_lifetimes() -> void:
	make()
	for k in int(rules.crowd_start):
		combat.place_item(&"frag", Vector2(2000 + k, FLOOR - 2), 100.0)
	assert_eq(combat.crowd_share(), 1.0, "at the threshold: full")
	for k in int(rules.crowd_full - rules.crowd_start):
		combat.place_item(&"frag", Vector2(2000 + k, FLOOR - 2), 100.0)
	assert_almost_eq(combat.crowd_share(), rules.crowd_min_share, 0.0001, "at full crowd: shortest")
	assert_almost_eq(combat.item_lifetime(combat.items[0]), 100.0 * rules.crowd_min_share, 0.001)


# US-22.1: spawn by distance from living enemies, at random among the better half,
# skipping points used in the last few seconds.
func test_us22_1_spawns_away_from_enemies() -> void:
	var xs := [200.0, 700.0, 1200.0, 1700.0, 2200.0, 2700.0, 3200.0, 3700.0]
	var spawns: Array = []
	for x in xs:
		spawns.append([Vector2(x, FLOOR), -1])
	make(Array(), Callable(), _map_with_points([], spawns))
	var enemy := add(250)
	var picks := {}
	for k in 40:
		combat.time += rules.spawn_reuse_block + 1.0
		var f := Fighter.new()
		var p := combat.choose_spawn(f)
		picks[p.position.x] = true
	for x: float in picks:
		assert_gt(x, 1900.0, "only the far half: %s" % x)
	assert_gt(picks.size(), 1, "random among them")


func test_us22_1_skips_recently_used_points() -> void:
	var spawns: Array = []
	for x in [500.0, 1500.0]:
		spawns.append([Vector2(x, FLOOR), -1])
	make(Array(), Callable(), _map_with_points([], spawns))
	var f := Fighter.new()
	var first := combat.choose_spawn(f)
	var second := combat.choose_spawn(f)
	assert_ne(first, second, "the used one is skipped")


func test_us22_1_explosives_count() -> void:
	var spawns: Array = []
	for x in [500.0, 3500.0]:
		spawns.append([Vector2(x, FLOOR), -1])
	make(Array(), Callable(), _map_with_points([], spawns))
	var g := CombatSim.Grenade.new()
	g.pos = Vector2(3400, FLOOR - 5)
	combat.grenades.append(g)
	var p := combat.choose_spawn(Fighter.new())
	assert_eq(p.position.x, 500.0, "away from the live frag")


# US-22.2: respawn after the respawn wait, no tap needed, with full kit and health.
func test_us22_2_respawn_after_wait() -> void:
	make()
	var me := add(400)
	var you := add(600)
	combat.hurt(you, rules.max_health, me.id(), &"pistol", CombatSim.Hurt.BULLET)
	var popped := sim.tick
	assert_true(run_until(func() -> bool: return you.alive, rules.respawn_wait + 1.0), "respawned")
	assert_almost_eq((sim.tick - popped) * TICK, rules.respawn_wait, TICK * 1.5, "after the wait")
	assert_eq(you.toy.health, rules.max_health)
	assert_eq(you.main_weapon().id(), &"pistol", "spawn kit again")
	assert_true(you.toy.active)
	assert_true(you.is_protected(), "with spawn protection")


# US-22.4: protection blocks bullets too, for its time.
func test_us22_4_protection_blocks_bullets() -> void:
	make()
	var me := add(400)
	var you := add(500, Fighter.NO_TEAM, true)
	weapon(&"pistol").spread = 0.0
	set_intent(me, AIM_RIGHT, true)
	var blocked := collect(&"blocked", rules.spawn_protection - 0.2)
	assert_gt(blocked.size(), 0, "bullets blocked")
	assert_eq(you.toy.health, rules.max_health)
	run(0.4)
	assert_lt(you.toy.health, rules.max_health, "protection ran out")


func test_us22_4_protection_lasts_its_time() -> void:
	make()
	var you := add(500, Fighter.NO_TEAM, true)
	run(rules.spawn_protection - 0.05)
	assert_true(you.is_protected())
	run(0.1)
	assert_false(you.is_protected())


# US-22.5: firing ends protection.
func test_us22_5_firing_ends_protection() -> void:
	make()
	var me := add(400, Fighter.NO_TEAM, true)
	set_intent(me, AIM_RIGHT, true)
	step()
	assert_false(me.is_protected())


func test_us22_5_grenade_and_melee_end_protection_too() -> void:
	make()
	var me := add(400, Fighter.NO_TEAM, true)
	press(me, InputIntent.Act.GRENADE)
	assert_false(me.is_protected(), "a throw")
	me.protect_left = rules.spawn_protection
	press(me, InputIntent.Act.MELEE)
	assert_false(me.is_protected(), "a swing")


# US-22.6: team spawns use the team's group.
func test_us22_6_team_spawns() -> void:
	make(Array(), Callable(), _map_with_points([], [[Vector2(500, FLOOR), 2], [Vector2(3500, FLOOR), 3], [Vector2(2000, FLOOR), -1]]))
	combat.team_spawns = true
	for k in 10:
		combat.time += rules.spawn_reuse_block + 1.0
		var f := Fighter.new()
		f.team = 3
		assert_eq(combat.choose_spawn(f).position.x, 3500.0)


# NF-12 for combat: the same inputs and seed give the same match.
func test_nf12_same_inputs_same_fight() -> void:
	var runs: Array = []
	for r in 2:
		make()
		var me := add(400)
		var you := add(700)
		arm(me, &"pump_shotgun")
		set_intent(me, AIM_RIGHT, true)
		set_intent(you, AIM_LEFT, true)
		var log: Array = []
		for k in ticks(3.0):
			step()
			for e in combat.events:
				log.append([e.type, e.get("toy", 0), snappedf(float(e.get("amount", 0.0)), 0.0001)])
		runs.append(log)
	assert_eq(runs[0], runs[1])


func test_us16_1_map_item_stays_on_its_ledge() -> void:
	make(Array(), Callable(), _map_with_points([[Vector2(1000, FLOOR - 300), ["smg"], -1.0]]))
	var ledge := Terrain.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(200, 20)
	cs.shape = shape
	cs.position = Vector2(1000, FLOOR - 290)
	ledge.add_child(cs)
	sim.map.add_child(ledge)
	run(1.0)
	assert_almost_eq(combat.items[0].pos.y, FLOOR - 300, 0.01, "stays on the ledge")


func test_us07_6_dropped_gun_falls_to_the_floor() -> void:
	make()
	var me := add(400)
	var you := add(600)
	you.toy.position.y -= 200
	combat.hurt(you, rules.max_health, me.id(), &"pistol", CombatSim.Hurt.BULLET)
	run(2.0)
	var it: CombatSim.FloorItem = combat.items[0]
	assert_true(it.resting)
	assert_almost_eq(it.pos.y, FLOOR, 1.0, "on the floor")
