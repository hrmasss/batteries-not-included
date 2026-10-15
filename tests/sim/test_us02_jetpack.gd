extends SimTest
## US-02: fly on the jetpack. Every expected number is read from the ruleset.


# US-02.1: the jetpack engages after the engage airtime with the stick past the engage
# deflection and pointing up.
func test_us02_1_engages_after_airtime() -> void:
	make()
	var engaged_at := -1
	for i in ticks(2.0):
		step_with(UP)
		if toy.jetpack_on:
			engaged_at = i
			break
	assert_gt(engaged_at, 0, "engaged")
	# Airtime starts on the first tick off the ground, one tick after the jump.
	assert_almost_eq((engaged_at - 1) * TICK, rules.engage_airtime, TICK * 1.5, "after the engage airtime")


func test_us02_1_not_below_the_engage_deflection() -> void:
	make()
	step_with(UP)
	var weak := Vector2(0, rules.engage_deflection - 0.05)
	# Above the jump threshold would re-jump; this stick is under both.
	hold(weak, 1.5)
	assert_false(toy.jetpack_on, "a short push does not take off")


func test_us02_1_not_when_pointing_too_low() -> void:
	make()
	step_with(UP)
	# Full deflection, but up below engage_up.
	var angle := asin(rules.engage_up - 0.05)
	hold(Vector2(cos(angle), sin(angle)), 1.0)
	assert_false(toy.jetpack_on, "pointing mostly sideways does not take off")


func test_us02_1_engages_from_a_fall_too() -> void:
	make()
	toy.position.y -= 600.0
	idle(rules.engage_airtime + 0.1)
	step_with(UP)
	assert_true(toy.jetpack_on, "falling long enough counts as airtime")


# US-02.2: flying uses flying gravity and eases toward fly speed along the stick, any way.
func test_us02_2_flying_gravity() -> void:
	make()
	take_off()
	# Thumb on the stick at its centre: no drive, just flying gravity and drag.
	var before := vel()
	step_with(Vector2.ZERO, true)
	var kept := pow(rules.speed_kept_per_second, TICK)
	var expected_dy := before.y * kept - rules.fly_gravity * TICK
	assert_almost_eq(vel().y, expected_dy, 0.5, "flying gravity, not walking gravity")


func test_us02_2_flies_toward_stick_any_direction() -> void:
	for stick: Vector2 in [UP, RIGHT, LEFT, DOWN, Vector2(1, 1).normalized(), Vector2(-1, -1).normalized()]:
		make()
		toy.position += Vector2(1600.0, -1500.0)
		take_off()
		hold(stick, 2.0)
		if not toy.jetpack_on:
			# Flying down into the floor lands; skip the rest for that stick.
			continue
		var along := vel().dot(stick)
		assert_gt(along, rules.fly_speed * 0.6, "moves along %s" % stick)
		var across := absf(vel().dot(Vector2(-stick.y, stick.x)))
		assert_lt(across, rules.fly_speed * 0.25, "little drift across %s" % stick)


func test_us02_2_flying_down_is_faster_than_falling() -> void:
	make()
	toy.position.y -= 3000.0
	take_off()
	hold(DOWN, 1.0)
	assert_lt(vel().y, -rules.fly_speed * 0.6, "stick down flies down")
	assert_true(toy.jetpack_on)


# US-02.3: drain at the drain rate for the stick's upward share.
func test_us02_3_drain_straight_up_and_sideways() -> void:
	for stick: Vector2 in [UP, RIGHT, Vector2(1, 1).normalized()]:
		make()
		toy.position.y -= 3000.0
		take_off()
		step_with(stick)
		var start := toy.battery
		hold(stick, 1.0)
		var expected := ToyMotor.drain_per_second(ToyMotor.thrust_share(stick.y, rules), rules)
		assert_almost_eq(start - toy.battery, expected, expected * 0.02, "drain per second for %s" % stick)
	assert_almost_eq(ToyMotor.drain_per_second(ToyMotor.thrust_share(1.0, rules), rules), rules.drain_rate, 0.0001, "full rate straight up")
	assert_almost_eq(ToyMotor.drain_per_second(ToyMotor.thrust_share(0.0, rules), rules), rules.drain_rate * rules.drain_floor_share, 0.0001, "floor share level")


# US-02.4: an empty battery disengages the jetpack and returns walking gravity.
func test_us02_4_empty_battery_drops_the_toy() -> void:
	make()
	take_off()
	var ran_out := false
	for i in ticks(10.0):
		step_with(UP)
		if toy.battery <= 0.0:
			ran_out = true
			break
	assert_true(ran_out, "battery ran out")
	step_with(UP)
	assert_false(toy.jetpack_on, "jetpack off")
	var before := vel().y
	step_with(UP)
	var kept := pow(rules.speed_kept_per_second, TICK)
	assert_almost_eq(vel().y, before * kept - rules.walk_gravity * TICK, 0.5, "walking gravity again")


# US-02.5: refill after the pause at the refill rate, up to full.
func test_us02_5_refill_pause_and_rate() -> void:
	make()
	take_off()
	hold(UP, 2.0)
	var low := toy.battery
	assert_lt(low, rules.battery_full)
	# Let go in the air: thrust stops.
	var first_gain := -1
	for i in ticks(3.0):
		sim.step()
		if toy.battery > low and first_gain < 0:
			first_gain = i
	assert_almost_eq(first_gain * TICK, rules.refill_pause, TICK * 1.5, "refill starts after the pause")
	var mid := toy.battery
	idle(1.0)
	assert_almost_eq(toy.battery - mid, minf(rules.refill_rate, rules.battery_full - mid), 0.2, "refill rate")
	idle(20.0)
	assert_eq(toy.battery, rules.battery_full, "stops at full")


func test_us02_5_refill_from_empty_takes_t25_refill() -> void:
	make()
	toy.battery = 0.0
	toy.since_thrust = 0.0
	var t := Drills.refill_time(sim, toy)
	var expected := rules.refill_pause + rules.battery_full / rules.refill_rate
	assert_almost_eq(t, expected, 0.1, "refill from empty")


# US-02.6: touching down with the stick pulled down below the cut-off, or letting go on the
# ground, disengages.
func test_us02_6_land_with_stick_down() -> void:
	make()
	take_off()
	hold(Vector2(0.3, 0.9), 0.3)
	# Pull down and keep pulling: once it touches down slower than the cut-off, flight ends.
	var off_on_ground := false
	for i in ticks(5.0):
		step_with(DOWN)
		if not toy.jetpack_on:
			off_on_ground = toy.foot_contact
			break
	assert_true(off_on_ground, "pulled down on landing: jetpack off, on the ground")
	hold(DOWN, 0.5)
	assert_false(toy.jetpack_on, "and stays off")
	assert_true(toy.crouched, "the held stick crouches the landed toy")


func test_us02_6_let_go_on_the_ground() -> void:
	make()
	take_off()
	# Fly sideways along the floor, then let go while touching it.
	hold(Vector2(0.9, 0.1), 0.2)
	toy.position.y = TestWorld.FLOOR_Y + rules.body_bottom - SimToy.SAFE_MARGIN
	toy.velocity.y = 0.0
	step_with(RIGHT)
	sim.step()
	if toy.foot_contact:
		sim.step()
	assert_false(toy.jetpack_on, "let go on the ground: jetpack off")


func test_us02_6_skimming_the_floor_with_stick_up_keeps_flying() -> void:
	make()
	take_off()
	hold(RIGHT, 0.5)
	# Touch the floor with the stick level, still held.
	toy.position.y = TestWorld.FLOOR_Y + rules.body_bottom - SimToy.SAFE_MARGIN
	step_with(RIGHT)
	step_with(RIGHT)
	assert_true(toy.jetpack_on, "stick level, still held: keeps flying")


func test_us02_6_fast_landing_with_stick_down_keeps_flying() -> void:
	make()
	toy.position.y -= 600.0
	take_off()
	hold(DOWN, 1.0)
	# Hit the floor fast, stick down: above the cut-off the jetpack stays on for that touch.
	var fast_touch := false
	for i in ticks(5.0):
		step_with(DOWN)
		if toy.foot_contact:
			# The next tick reads the contact; the toy still moves faster than the cut-off.
			fast_touch = toy.speed() >= rules.landing_cutoff_speed
			step_with(DOWN)
			break
	gut.p("speed after a full-speed dive into the floor: %.1f u/s" % toy.speed())
	assert_true(fast_touch, "touched down above the cut-off")
	assert_true(toy.jetpack_on, "still flying")


# US-02.7: keep T-7 of the speed per second in the air; never pass the top speed.
func test_us02_7_air_drag() -> void:
	make()
	toy.position.y -= 3000.0
	toy.velocity = Vector2(400, 0)
	idle(1.0)
	assert_almost_eq(toy.velocity.x, 400.0 * rules.speed_kept_per_second, 2.0, "keeps T-7 of its sideways speed per second")


func test_us02_7_top_speed() -> void:
	make()
	toy.position.y -= 3000.0
	toy.velocity = Vector2(rules.top_speed * 3.0, 0)
	sim.step()
	assert_lte(toy.speed(), rules.top_speed + 0.001, "capped at once")
	# A long dive with the jetpack: never past the top speed.
	toy.velocity = Vector2.ZERO
	take_off()
	var top := 0.0
	for i in ticks(4.0):
		step_with(DOWN)
		top = maxf(top, toy.speed())
	assert_lte(top, rules.top_speed + 0.001)


# US-02.8: a full battery spent straight up flies for the T-25 full-up flight time, within 0.1 s.
func test_us02_8_full_up_flight_time() -> void:
	make()
	var flown := Drills.full_up_flight(sim, toy)
	var t25 := rules.battery_full / rules.drain_rate
	gut.p("full-up flight: %.3f s (T-25 from the ruleset: %.3f s; 04_tuning: about 4.8 s)" % [flown, t25])
	assert_almost_eq(flown, t25, 0.1, "T-25 from this ruleset")
	assert_almost_eq(flown, 4.8, 0.1, "T-25 start value, about 4.8 s")


# US-02.9: a map or ruleset battery size is used as full.
func test_us02_9_ruleset_battery_size() -> void:
	var r := TestWorld.rules()
	r.battery_full = 50.0
	make(r)
	assert_eq(toy.battery, 50.0)
	assert_almost_eq(Drills.full_up_flight(sim, toy), 50.0 / r.drain_rate, 0.1)


func test_us02_9_map_battery_size() -> void:
	var m := TestWorld.map()
	m.battery_full = 15.0
	make(null, m)
	assert_eq(toy.battery, 15.0, "the map's battery (the classic's ice maps use 15)")
	idle(15.0)
	assert_eq(toy.battery, 15.0, "refills only to the map's full")


func test_us02_9_modifier_beats_map() -> void:
	var r := TestWorld.rules()
	r.battery_size = 30.0
	var m := TestWorld.map()
	m.battery_full = 15.0
	make(r, m)
	assert_eq(toy.battery, 30.0, "a battery-size modifier overrides the map")


# US-02.10: Batteries Included keeps every battery full.
func test_us02_10_batteries_included() -> void:
	var r := TestWorld.rules()
	r.batteries_included = true
	make(r)
	toy.position.y -= 5000.0
	take_off()
	var lowest := toy.battery
	for i in ticks(10.0):
		step_with(UP)
		lowest = minf(lowest, toy.battery)
	assert_eq(lowest, r.battery_full, "never drains")
	assert_true(toy.jetpack_on, "still flying after twice the full-up flight time")
