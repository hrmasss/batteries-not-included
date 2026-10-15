extends CombatTest
## US-05: aim and fire with one thumb. Sim checks.


func _shots(f: Fighter, seconds: float) -> int:
	var n := 0
	for k in ticks(seconds):
		step()
		for e in events_of(&"shot"):
			if e.toy == f.id():
				n += 1
	return n


# US-05.1: the aim follows the thumb's angle at any distance from the centre.
func test_us05_1_aim_follows_angle_not_distance() -> void:
	make()
	var me := add(400)
	weapon(&"pistol").spread = 0.0
	for stick in [Vector2(0.1, 0.1), Vector2(0.7, 0.7)]:
		set_intent(me, stick, true)
		step()
		var b: CombatSim.Bullet = combat.bullets.back()
		var dir := Vector2(b.vel.x, -b.vel.y).normalized()
		assert_almost_eq(dir.angle(), Vector2(1, 1).angle(), 0.001, "aim %s fires along 45 degrees" % stick)
		set_intent(me, stick, false)
		run(1.0)


# US-05.2: fire while past the ring (the intent's fire), stop when it comes back.
func test_us05_2_fires_while_held_and_stops_on_release() -> void:
	make()
	var me := add(400)
	set_intent(me, AIM_RIGHT, true)
	assert_gt(_shots(me, 1.0), 0, "fires while held")
	set_intent(me, AIM_RIGHT, false)
	step()
	assert_eq(_shots(me, 1.0), 0, "stops when let go")


# US-05.3: once per fire interval while the magazine holds rounds.
func test_us05_3_fire_rate_follows_interval() -> void:
	for id: StringName in [&"pistol", &"smg", &"assault_rifle"]:
		make()
		var me := add(400)
		arm(me, id)
		var d := weapon(id)
		var window := (d.mag - 1) * d.interval
		set_intent(me, AIM_RIGHT, true)
		var n := _shots(me, window)
		assert_almost_eq(float(n), window / d.interval, 1.0, "%s: one shot per %s s" % [id, d.interval])


func test_us05_3_stops_when_magazine_is_empty() -> void:
	make()
	var me := add(400)
	arm(me, &"pistol")
	me.main_weapon().reserve = 0
	set_intent(me, AIM_RIGHT, true)
	var n := _shots(me, weapon(&"pistol").interval * (weapon(&"pistol").mag + 5))
	assert_eq(n, weapon(&"pistol").mag, "a magazine's worth and no more")
	assert_eq(me.main_weapon().mag, 0)


# US-05.4: every pellet goes at random within the spread of the aim, rolled by the match.
func test_us05_4_pellets_within_spread_at_random() -> void:
	make()
	var me := add(400)
	arm(me, &"pump_shotgun")
	var d := weapon(&"pump_shotgun")
	set_intent(me, AIM_RIGHT, true)
	step()
	assert_eq(combat.bullets.size(), d.pellets, "one bullet per pellet")
	var angles: Array[float] = []
	for b in combat.bullets:
		var a := rad_to_deg(Vector2(b.vel.x, -b.vel.y).angle())
		assert_between(a, -d.spread - 0.001, d.spread + 0.001, "pellet inside the spread")
		angles.append(a)
	var distinct := {}
	for a in angles:
		distinct[snappedf(a, 0.01)] = true
	assert_gt(distinct.size(), 1, "pellets do not all go the same way")


func test_us05_4_spread_is_rolled_by_the_seeded_match() -> void:
	var runs: Array = []
	for r in 2:
		make()
		var me := add(400)
		arm(me, &"pump_shotgun")
		set_intent(me, AIM_RIGHT, true)
		step()
		runs.append(combat.bullets.map(func(b: CombatSim.Bullet) -> Vector2: return b.vel))
	assert_eq(runs[0], runs[1], "the same seed rolls the same spread")


# US-05.5: an empty magazine reloads by itself; the reload button reloads a part-empty one.
func test_us05_5_empty_magazine_reloads_and_moves_what_fits() -> void:
	make()
	var me := add(400)
	arm(me, &"pistol")
	var d := weapon(&"pistol")
	var w := me.main_weapon()
	set_intent(me, AIM_RIGHT, true)
	assert_true(run_until(func() -> bool: return w.reloading(), d.interval * (d.mag + 2)), "reloads when empty")
	set_intent(me, AIM_RIGHT, false)
	var reserve_before := w.reserve
	assert_true(run_until(func() -> bool: return not w.reloading(), d.reload + 0.1), "reload ends")
	assert_eq(w.mag, d.mag, "magazine full")
	assert_eq(w.reserve, reserve_before - d.mag, "reserve gave what fit")


func test_us05_5_reload_takes_the_reload_time() -> void:
	make()
	var me := add(400)
	arm(me, &"assault_rifle")
	var d := weapon(&"assault_rifle")
	var w := me.main_weapon()
	w.mag = 5
	press(me, InputIntent.Act.RELOAD)
	assert_true(w.reloading(), "the button reloads a part-empty magazine")
	var started := sim.tick - 1
	run_until(func() -> bool: return not w.reloading(), d.reload + 1.0)
	assert_almost_eq((sim.tick - started) * TICK, d.reload, TICK * 1.5, "takes the reload time")
	assert_eq(w.mag, d.mag)


func test_us05_5_no_reload_when_full_or_no_reserve() -> void:
	make()
	var me := add(400)
	var w := me.main_weapon()
	press(me, InputIntent.Act.RELOAD)
	assert_false(w.reloading(), "full magazine: no reload")
	w.mag = 3
	w.reserve = 0
	press(me, InputIntent.Act.RELOAD)
	assert_false(w.reloading(), "no reserve: no reload")


func test_us05_5_partial_reserve_fills_partly() -> void:
	make()
	var me := add(400)
	var w := me.main_weapon()
	w.mag = 0
	w.reserve = 4
	w.start_reload()
	run(w.def.reload + 0.1)
	assert_eq(w.mag, 4)
	assert_eq(w.reserve, 0)


# T-50 special kinds by data: burst and spin-up (US-11.4 groundwork).
func test_burst_and_spin_up_by_data() -> void:
	make(Array(), func(r: Ruleset) -> void:
		var d := r.weapons.get_def(&"assault_rifle")
		d.burst = 3
		d.burst_gap = 0.06
		d.interval = 0.5
		r.weapons.get_def(&"smg").spin_up = 1.0)
	var me := add(400)
	arm(me, &"assault_rifle")
	set_intent(me, AIM_RIGHT, true)
	var first := sim.tick
	var shots: Array[int] = []
	for k in ticks(0.45):
		step()
		for e in events_of(&"shot"):
			shots.append(sim.tick - first)
	assert_eq(shots.size(), 3, "one pull, three rounds")
	assert_almost_eq((shots[2] - shots[0]) * TICK, 0.12, TICK * 1.5, "0.06 s apart")
	arm(me, &"smg")
	set_intent(me, AIM_RIGHT, true)
	var started := sim.tick
	run_until(func() -> bool: return not events_of(&"shot").is_empty(), 2.0)
	assert_almost_eq((sim.tick - started) * TICK, 1.0, TICK * 2.0, "spin-up: first shot after 1 s")
