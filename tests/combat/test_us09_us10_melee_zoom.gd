extends CombatTest
## US-09 melee; US-10 zoom; US-11.3 weapons as data. Sim checks.


# US-09.1: melee swings for the swing time and lunges along the aim.
func test_us09_1_swing_and_lunge() -> void:
	make()
	var me := add(400)
	var meter := me.lunge_meter
	set_intent(me, AIM_RIGHT, false, InputIntent.Act.MELEE)
	step()
	assert_almost_eq(me.swing_left, rules.melee_swing - TICK, TICK * 0.5, "swinging")
	assert_gt(me.toy.velocity.x, meter * 0.5, "lunges along the aim")
	assert_almost_eq(me.lunge_meter, meter - rules.lunge_cost + rules.lunge_refill * TICK, 0.01, "spent from the meter")


# US-09.2: a swing reaching an enemy deals the weapon's melee damage; bare hands otherwise.
func test_us09_2_melee_damage() -> void:
	make()
	var me := add(400)
	var you := add(420)
	set_intent(me, AIM_RIGHT, false, InputIntent.Act.MELEE)
	var hits := collect(&"hit", rules.melee_swing + 0.1)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, weapon(&"pistol").melee_damage, "the pistol's melee")
	assert_eq(hits[0].kind, CombatSim.Hurt.MELEE)


func test_us09_2_bare_hands() -> void:
	make()
	var me := add(400)
	var you := add(420)
	me.weapons.clear()
	set_intent(me, AIM_RIGHT, false, InputIntent.Act.MELEE)
	var hits := collect(&"hit", rules.melee_swing + 0.1)
	assert_eq(hits[0].amount, rules.bare_hand_damage)


func test_us09_2_out_of_reach_misses() -> void:
	make()
	var me := add(400)
	var you := add(400 + 300)
	set_intent(me, AIM_RIGHT, false, InputIntent.Act.MELEE)
	assert_eq(collect(&"hit", rules.melee_swing + 0.1).size(), 0)


func test_us06_4_melee_passes_teammates() -> void:
	make()
	var me := add(400, 2)
	var mate := add(420, 2)
	press(me, InputIntent.Act.MELEE)
	run(rules.melee_swing + 0.1)
	assert_eq(mate.toy.health, rules.max_health)


# US-09.3: with the meter spent, swings go without the lunge until it refills.
func test_us09_3_spent_meter_no_lunge() -> void:
	make()
	var me := add(400)
	me.lunge_meter = rules.lunge_cost * 0.5
	set_intent(me, AIM_UP, false, InputIntent.Act.MELEE)
	step()
	assert_false(events_of(&"swing")[0].lunge, "no lunge")
	set_intent(me, AIM_UP)
	run((rules.lunge_cost * 0.5) / rules.lunge_refill + rules.melee_swing + 0.1)
	set_intent(me, AIM_UP, false, InputIntent.Act.MELEE)
	step()
	assert_true(events_of(&"swing")[0].lunge, "refilled: lunges again")


# US-09.4: melee never gets the headshot factor.
func test_us09_4_no_headshot_on_melee() -> void:
	make()
	var me := add(400)
	var you := add(420)
	set_intent(me, AIM_RIGHT, false, InputIntent.Act.MELEE)
	var hits := collect(&"hit", rules.melee_swing + 0.1)
	assert_false(hits[0].head)
	assert_eq(hits[0].amount, weapon(&"pistol").melee_damage)


# US-10.1: each weapon steps only through its own zoom levels.
func test_us10_1_only_allowed_levels() -> void:
	make()
	var me := add(400)
	for id: StringName in [&"pistol", &"sniper_rifle", &"assault_rifle"]:
		arm(me, id)
		me.zoom_level = weapon(id).zoom[0]
		var seen: Array[int] = []
		for k in weapon(id).zoom.size():
			press(me, InputIntent.Act.ZOOM)
			seen.append(me.zoom_level)
			assert_true(weapon(id).zoom.has(me.zoom_level), "%s allows %d" % [id, me.zoom_level])
		assert_eq(seen.back(), weapon(id).zoom[0], "%s wraps back to its first level" % id)


# US-10.3: a weapon change returns to the level last used with it, or the nearest allowed.
func test_us10_3_zoom_memory_and_nearest() -> void:
	make()
	var me := add(400)
	arm(me, &"pistol", &"sniper_rifle")
	press(me, InputIntent.Act.ZOOM)
	assert_eq(me.zoom_level, 2, "pistol to 2X")
	press(me, InputIntent.Act.SWITCH)
	assert_eq(me.zoom_level, 1, "sniper has no 2X: nearest allowed, the wider on a tie")
	press(me, InputIntent.Act.ZOOM)
	press(me, InputIntent.Act.ZOOM)
	press(me, InputIntent.Act.ZOOM)
	assert_eq(me.zoom_level, 7, "sniper to 7X")
	press(me, InputIntent.Act.SWITCH)
	assert_eq(me.zoom_level, 2, "back to the pistol's last level")
	press(me, InputIntent.Act.SWITCH)
	assert_eq(me.zoom_level, 7, "back to the sniper's last level")


# US-11.3: a new weapon of an existing kind is data alone.
func test_us11_3_new_weapon_by_data_alone() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://data/rulesets/standard/weapons.cfg"), OK)
	for key: String in cfg.get_section_keys("pistol"):
		cfg.set_value("water_pistol", key, cfg.get_value("pistol", key))
	cfg.set_value("water_pistol", "name", "Water pistol")
	cfg.set_value("water_pistol", "damage", 3.0)
	var res := WeaponTable.from_config(cfg)
	assert_true(res.ok(), ", ".join(res.errors))
	make(Array(), func(r: Ruleset) -> void: r.weapons = res.table)
	var me := add(400)
	var you := add(500)
	arm(me, &"water_pistol")
	weapon(&"water_pistol").spread = 0.0
	set_intent(me, AIM_RIGHT, true)
	var hits := collect(&"hit", 0.2)
	assert_eq(hits[0].weapon, &"water_pistol")
	assert_eq(hits[0].amount, 3.0)


func test_us43_2_bad_weapon_row_is_refused_and_named() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://data/rulesets/standard/weapons.cfg")
	cfg.set_value("uzi", "spread", -4.0)
	cfg.set_value("smg", "zoom", [3, 1])
	cfg.erase_section_key("pump_shotgun", "pellets")
	var res := WeaponTable.from_config(cfg)
	assert_false(res.ok())
	var all := "\n".join(res.errors)
	assert_string_contains(all, "weapons.uzi.spread (T-50)")
	assert_string_contains(all, "weapons.smg.zoom")
	assert_string_contains(all, "weapons.pump_shotgun.pellets (T-50): missing")


func test_launch_weapons_are_in_the_table() -> void:
	# US-11.1 (Review), checked here so a missing row fails the build.
	make()
	for id: StringName in [&"pistol", &"uzi", &"smg", &"assault_rifle", &"pump_shotgun", &"sniper_rifle", &"rocket_launcher"]:
		assert_true(rules.weapons.has(id), "%s in the table" % id)
