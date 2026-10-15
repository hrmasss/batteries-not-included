extends CombatTest
## US-07 carry, swap and pick up; US-08 dual wield. Sim checks.


# US-07.2: a spawn gets the ruleset's kit: a pistol, melee and 2 frags by default.
func test_us07_2_spawn_kit() -> void:
	make()
	var me := combat.spawn()
	assert_eq(me.weapons.size(), rules.weapons.kit_weapons.size())
	assert_eq(me.main_weapon().id(), &"pistol", "a pistol")
	assert_eq(me.grenades.get(&"frag", 0), 2, "two frags")
	assert_eq(me.grenade_count(), rules.weapons.kit_grenades.size())


# US-07.1: two weapons and grenades at once.
func test_us07_1_carries_two_weapons_and_grenades() -> void:
	make()
	var me := add(400)
	combat.place_item(&"smg", me.toy.position)
	step()
	press(me, InputIntent.Act.PICK_UP)
	assert_eq(me.weapons.size(), 2, "two weapons")
	assert_eq(me.grenade_count(), 2, "and the grenades")


# US-07.3: a weapon within reach is offered; taking it with both hands full swaps the held one.
func test_us07_3_offer_within_reach_only() -> void:
	make()
	var me := add(400)
	var near := combat.place_item(&"smg", me.toy.position + Vector2(rules.pickup_reach - 5, -rules.pickup_reach_up))
	step()
	assert_eq(me.offer, near.uid, "offered within reach")
	near.pos += Vector2(20, 0)
	near.resting = true
	step()
	assert_eq(me.offer, -1, "not offered out of reach")
	press(me, InputIntent.Act.PICK_UP)
	assert_eq(me.weapons.size(), 1, "nothing taken out of reach")


func test_us07_3_take_swaps_held_and_drops_old() -> void:
	make()
	var me := add(400)
	arm(me, &"pistol", &"smg")
	me.held = 1
	combat.place_item(&"assault_rifle", me.toy.position)
	step()
	press(me, InputIntent.Act.PICK_UP)
	assert_eq(me.weapons.size(), 2)
	assert_eq(me.main_weapon().id(), &"assault_rifle", "now holds the new one")
	assert_eq(me.weapons[0].id(), &"pistol", "the other slot kept")
	var dropped := combat.items.filter(func(it: CombatSim.FloorItem) -> bool: return it.item == &"smg")
	assert_eq(dropped.size(), 1, "the old one is on the floor")


func test_us07_3_dropped_gun_keeps_its_ammo() -> void:
	make()
	var me := add(400)
	arm(me, &"pistol", &"smg")
	me.held = 1
	me.main_weapon().mag = 3
	me.main_weapon().reserve = 7
	combat.place_item(&"assault_rifle", me.toy.position)
	step()
	press(me, InputIntent.Act.PICK_UP)
	var smg: CombatSim.FloorItem = combat.items.filter(func(it: CombatSim.FloorItem) -> bool: return it.item == &"smg")[0]
	assert_eq([smg.weapon.mag, smg.weapon.reserve], [3, 7])


# US-07.4: switch swaps the held weapon for the other one.
func test_us07_4_switch() -> void:
	make()
	var me := add(400)
	arm(me, &"pistol", &"smg")
	assert_eq(me.main_weapon().id(), &"pistol")
	press(me, InputIntent.Act.SWITCH)
	assert_eq(me.main_weapon().id(), &"smg")
	press(me, InputIntent.Act.SWITCH)
	assert_eq(me.main_weapon().id(), &"pistol")


func test_us07_4_held_weapon_sets_the_weight() -> void:
	make()
	var me := add(400)
	arm(me, &"pistol", &"sniper_rifle")
	step()
	assert_almost_eq(me.toy.weight_factor(rules), weapon(&"pistol").weight, 0.0001)
	press(me, InputIntent.Act.SWITCH)
	assert_almost_eq(me.toy.weight_factor(rules), weapon(&"sniper_rifle").weight, 0.0001, "T-19: the held weapon's weight")


# US-07.6: a popped toy drops its held weapon as a pickup.
func test_us07_6_pop_drops_held_weapon() -> void:
	make()
	var me := add(400)
	var you := add(600)
	arm(you, &"smg")
	combat.hurt(you, rules.max_health, me.id(), &"pistol", CombatSim.Hurt.BULLET)
	assert_false(you.alive)
	var dropped := combat.items.filter(func(it: CombatSim.FloorItem) -> bool: return it.item == &"smg")
	assert_eq(dropped.size(), 1, "the smg lies where it popped")


# US-08.1: two dual-capable weapons go one in each hand; others do not.
func test_us08_1_dual_only_when_both_are_dual_capable() -> void:
	make()
	var me := add(400)
	arm(me, &"pistol", &"uzi")
	assert_true(me.is_dual(), "pistol and Uzi: dual")
	arm(me, &"pistol", &"smg")
	assert_false(me.is_dual(), "pistol and SMG: not dual")
	arm(me, &"pistol", &"pistol")
	assert_true(me.is_dual(), "two pistols: dual")


func test_us08_1_picking_a_second_dual_weapon_makes_a_pair() -> void:
	make()
	var me := add(400)
	combat.place_item(&"uzi", me.toy.position)
	step()
	press(me, InputIntent.Act.PICK_UP)
	assert_true(me.is_dual(), "spawn pistol plus a picked-up Uzi")


# US-08.2: both fire, each on its own interval and magazine.
func test_us08_2_both_hands_fire_on_their_own_clocks() -> void:
	make()
	var me := add(400)
	arm(me, &"pistol", &"uzi")
	var pistol := me.weapons[0]
	var uzi := me.weapons[1]
	set_intent(me, AIM_RIGHT, true)
	run(0.95)
	set_intent(me, AIM_RIGHT, false)
	step()
	assert_eq(pistol.def.mag - pistol.mag, 4, "pistol: one per 0.25 s")
	assert_eq(uzi.def.mag - uzi.mag, 10, "Uzi: one per 0.1 s")


# US-08.3: the off-hand weapon counts at half its weight (T-19).
func test_us08_3_off_hand_half_weight() -> void:
	make(Array(), func(r: Ruleset) -> void: r.weapons.get_def(&"uzi").weight = 0.5)
	var me := add(400)
	arm(me, &"pistol", &"uzi")
	step()
	assert_almost_eq(me.toy.weight_factor(rules), 1.0 * (0.5 + 1.0) / 2.0, 0.0001)
