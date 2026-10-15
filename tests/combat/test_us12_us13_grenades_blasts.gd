extends CombatTest
## US-12 throw grenades; US-13 blasts hurt everyone nearby. Sim checks.


# US-12.1: thrown along the aim at the throw speed plus the toy's velocity.
func test_us12_1_throw_along_aim_plus_velocity() -> void:
	make()
	var me := add(400)
	me.toy.velocity = Vector2(50, 0)
	var aim := Vector2(1, 1).normalized()
	set_intent(me, aim, false, InputIntent.Act.GRENADE)
	var v_before := me.toy.velocity
	step()
	assert_eq(combat.grenades.size(), 1)
	var g: CombatSim.Grenade = combat.grenades[0]
	var world_aim := Vector2(aim.x, -aim.y)
	# The grenade has flown one tick: drag and gravity took a hair off.
	var expect := me.toy.velocity + world_aim * rules.throw_speed
	assert_almost_eq(g.vel.x, expect.x, 3.0)
	assert_almost_eq(g.vel.y, expect.y, rules.frag_gravity * TICK + 3.0)
	assert_eq(me.grenade_count(), 1, "one frag used")


func test_us12_1_no_grenade_no_throw() -> void:
	make()
	var me := add(400)
	me.grenades.clear()
	press(me, InputIntent.Act.GRENADE)
	assert_eq(combat.grenades.size(), 0)


# US-12.2: a frag bounces until its fuse runs out, then blasts.
func test_us12_2_frag_bounces_then_blasts_on_fuse() -> void:
	make()
	var me := add(400)
	set_intent(me, AIM_DOWN, false, InputIntent.Act.GRENADE)
	step()
	set_intent(me, AIM_DOWN)
	var g: CombatSim.Grenade = combat.grenades[0]
	var thrown := sim.tick - 1
	var bounced := false
	var blasts: Array[Dictionary] = []
	for k in ticks(rules.frag_fuse + 0.2):
		step()
		if g.vel.y < 0.0:
			bounced = true
		blasts.append_array(events_of(&"blast"))
		if not blasts.is_empty():
			break
	assert_true(bounced, "bounced off the floor")
	assert_eq(blasts.size(), 1, "one blast")
	assert_almost_eq((sim.tick - thrown) * TICK, rules.frag_fuse, TICK * 1.5, "at the fuse")
	assert_true(g.pos.y <= FLOOR, "never fell through the floor")


# US-12.3: at the cap, grenade pickups stay on the floor.
func test_us12_3_grenade_cap() -> void:
	make()
	var me := add(400)
	me.grenades = {&"frag": int(rules.grenade_cap) - 1}
	combat.place_item(&"frag", me.toy.position)
	combat.place_item(&"frag", me.toy.position)
	run(0.2)
	assert_eq(me.grenade_count(), int(rules.grenade_cap), "took one up to the cap")
	assert_eq(combat.items.size(), 1, "the other stays")


# US-12.4: grenade switch moves to the next type the toy holds.
func test_us12_4_grenade_switch_moves_to_a_held_type() -> void:
	make()
	var me := add(400)
	me.grenade_type = &"none_left"
	press(me, InputIntent.Act.GRENADE_SWITCH)
	assert_eq(me.grenade_type, &"frag", "moves to the type it holds")


func _frag_at(at: Vector2, owner: Fighter) -> void:
	combat.blast(at, rules.frag_power, owner.id(), &"frag")


func _expected(d: float) -> float:
	var p := rules.frag_power
	return maxf((rules.blast_damage * p - rules.blast_falloff * d) * p, rules.blast_min_damage)


# US-13.1: every toy inside the radius by distance, the thrower and teammates included.
func test_us13_1_blast_hurts_thrower_teammates_and_enemies() -> void:
	make()
	var me := add(400, 2)
	var mate := add(450, 2)
	var enemy := add(500, 3)
	var far := add(400 + rules.blast_radius * rules.frag_power + 60, 3)
	var at := Vector2(420, FLOOR - 20)
	_frag_at(at, me)
	for f in [me, mate, enemy]:
		var d := at.distance_to(f.toy.position)
		assert_almost_eq(rules.max_health - f.toy.health, _expected(d), 0.01, "toy %d hurt by distance" % f.id())
	assert_eq(far.toy.health, rules.max_health, "outside the radius: untouched")


func test_us13_1_damage_floors_at_the_minimum_inside_the_radius() -> void:
	make()
	var me := add(400)
	var you := add(500)
	var r := rules.blast_radius * rules.frag_power
	var at := you.toy.position + Vector2(-(r - 1.0), 0)
	_frag_at(at, me)
	assert_almost_eq(rules.max_health - you.toy.health, rules.blast_min_damage, 0.01)


# US-13.2: a wall between blast and toy leaves only the minimum.
func test_us13_2_wall_leaves_minimum_damage() -> void:
	make([Rect2(470, FLOOR - 200, 10, 200)])
	var me := add(300)
	var you := add(520)
	_frag_at(Vector2(440, FLOOR - 15), me)
	assert_almost_eq(rules.max_health - you.toy.health, rules.blast_min_damage, 0.01)
	assert_almost_eq(you.toy.velocity.length(), 0.0, 0.01, "and no knockback through the wall")


# US-13.3: spawn protection spares a toy from blasts.
func test_us13_3_protection_spares_from_blasts() -> void:
	make()
	var me := add(300)
	var you := add(400, Fighter.NO_TEAM, true)
	_frag_at(you.toy.position + Vector2(-10, 0), me)
	assert_eq(you.toy.health, rules.max_health)


# US-13.4: knock toys back and tell screens within reach to shake.
func test_us13_4_knockback_and_shake() -> void:
	make()
	var me := add(300)
	var you := add(400)
	var at := you.toy.position + Vector2(-40, 0)
	_frag_at(at, me)
	assert_gt(you.toy.velocity.x, 0.0, "pushed away from the blast")
	var d := at.distance_to(you.toy.position)
	assert_almost_eq(you.toy.velocity.length(), minf(_expected(d), rules.blast_knockback_cap) * rules.blast_knockback_per_hp, 0.01)
	var b: Dictionary = events_of(&"blast")[0]
	assert_eq(b.shake_reach, rules.blast_shake_reach * rules.frag_power, "screens within reach shake")


# US-13.5: popping yourself is a suicide and a death; popping a teammate a team kill, no credit.
func test_us13_5_self_pop_is_suicide() -> void:
	make()
	var me := add(400)
	me.toy.health = 5.0
	_frag_at(me.toy.position, me)
	assert_false(me.alive)
	assert_eq([me.kills, me.deaths, me.suicides], [0, 1, 1])


func test_us13_5_team_kill_no_credit() -> void:
	make()
	var me := add(300, 2)
	var mate := add(400, 2)
	mate.toy.health = 5.0
	_frag_at(mate.toy.position, me)
	assert_false(mate.alive)
	assert_eq([me.kills, me.suicides, me.team_kills], [0, 1, 1], "a suicide for the thrower, no kill")
	assert_eq(mate.deaths, 1)


func test_us12_us13_thrown_frag_hurts_the_thrower() -> void:
	# The whole path: throw at your feet, wait for the fuse.
	make()
	var me := add(400)
	set_intent(me, AIM_DOWN, false, InputIntent.Act.GRENADE)
	step()
	set_intent(me, AIM_DOWN)
	run(rules.frag_fuse + 0.1)
	assert_lt(me.toy.health, rules.max_health - rules.blast_min_damage, "own frag hurts")


# T-67: rockets hit directly, blast on walls once armed.
func test_rocket_direct_hit_and_blast() -> void:
	make()
	var me := add(300)
	var you := add(500)
	arm(me, &"rocket_launcher")
	set_intent(me, AIM_RIGHT, true)
	step()
	set_intent(me, AIM_RIGHT)
	var hits := collect(&"hit", 1.0)
	var kinds := hits.filter(func(h: Dictionary) -> bool: return h.toy == you.id()).map(func(h: Dictionary) -> int: return h.kind)
	assert_true(kinds.has(CombatSim.Hurt.DIRECT), "direct hit")
	assert_false(you.alive, "direct hit plus blast pops a full-health toy")


func test_rocket_unarmed_bounces_armed_blasts() -> void:
	make([Rect2(320, FLOOR - 300, 10, 300)])
	var me := add(300)
	arm(me, &"rocket_launcher")
	set_intent(me, AIM_RIGHT, true)
	step()
	set_intent(me, AIM_RIGHT)
	assert_eq(collect(&"blast", 0.05).size(), 0, "too close to arm: no blast on the wall")
	make([Rect2(600, FLOOR - 300, 10, 300)])
	me = add(300)
	arm(me, &"rocket_launcher")
	set_intent(me, AIM_RIGHT, true)
	step()
	set_intent(me, AIM_RIGHT)
	assert_eq(collect(&"blast", 1.0).size(), 1, "armed: blasts on the wall")
