extends SimTest
## US-01: walk, jump and crouch. Every expected number is read from the ruleset.


# US-01.1: on the ground, sideways stick eases toward the walk speed at the catch-up rate.
func test_us01_1_walk_eases_toward_walk_speed() -> void:
	make()
	step_with(RIGHT)
	# One tick closes catch-up × dt of the missing speed, less contact friction and drag.
	var first := rules.walk_catch_up * TICK * rules.walk_speed
	assert_between(vel().x, first * 0.8, first * 1.0001, "first tick closes catch-up × dt of the gap")
	var prev := vel().x
	var gains: Array[float] = []
	for i in 30:
		step_with(RIGHT)
		gains.append(vel().x - prev)
		prev = vel().x
	assert_gt(gains[0], gains[29], "eases: the gain shrinks as the gap closes")
	hold(RIGHT, 3.0)
	assert_between(vel().x, rules.walk_speed * 0.6, rules.walk_speed, "settles below the walk speed (drag and friction)")
	assert_true(toy.foot_contact, "stays on the ground")


func test_us01_1_half_stick_walks_slower() -> void:
	make()
	var full := Drills.top_walk_speed(sim, toy, 3.0, 1.0)
	make()
	var half := Drills.top_walk_speed(sim, toy, 3.0, 0.5)
	assert_between(half, full * 0.3, full * 0.6, "half stick, slower walk")


func test_us01_1_walk_left() -> void:
	make()
	hold(LEFT, 1.0)
	assert_lt(vel().x, -rules.walk_speed * 0.5)


# US-01.2: stick up past the threshold jumps, within grace, at most once per cooldown.
func test_us01_2_jump_adds_jump_speed() -> void:
	make()
	step_with(UP)
	# The jump adds jump_speed; the first half-ticks of gravity and drag take a little off.
	assert_between(vel().y, rules.jump_speed - rules.walk_gravity * TICK - 5.0, rules.jump_speed, "jump speed")
	assert_false(toy.foot_contact, "left the ground")


func test_us01_2_stick_below_threshold_does_not_jump() -> void:
	make()
	hold(Vector2(0, rules.jump_stick_up - 0.05), 0.5)
	assert_almost_eq(height(), 0.0, 1.0, "no jump below the threshold")


func test_us01_2_jump_cooldown() -> void:
	make()
	var rest := toy.position
	step_with(UP)
	assert_gt(vel().y, rules.jump_speed * 0.8, "first jump")
	# Put the toy straight back on the ground: the cooldown still blocks a second jump.
	toy.position = rest
	toy.velocity = Vector2.ZERO
	sim.step()
	var blocked := 0
	while toy.since_jump <= rules.jump_cooldown - TICK:
		step_with(UP)
		assert_lt(vel().y, rules.jump_speed * 0.5, "no jump %.2f s after the last" % toy.since_jump)
		toy.position = rest
		toy.velocity = Vector2.ZERO
		blocked += 1
	assert_gt(blocked, 0)
	idle(TICK * 2)
	step_with(UP)
	assert_gt(vel().y, rules.jump_speed * 0.8, "jumps again once the cooldown has passed")


func test_us01_2_ground_grace_after_walking_off_a_ledge() -> void:
	# A ledge at 200 u above the floor; the toy walks off its right edge.
	var ledge := Rect2(0, TestWorld.FLOOR_Y - 200, 600, 40)
	make(null, TestWorld.map(4000.0, [ledge], Vector2(560, TestWorld.FLOOR_Y - 200)))
	var left_ground := -1
	for i in ticks(2.0):
		step_with(RIGHT)
		if not toy.foot_contact:
			left_ground = sim.tick
			break
	assert_gt(left_ground, 0, "walked off")
	# Within the grace: jump works.
	step_with(UP)
	assert_gt(vel().y, rules.jump_speed * 0.8, "jump inside the grace")


func test_us01_2_no_jump_after_grace() -> void:
	var ledge := Rect2(0, TestWorld.FLOOR_Y - 400, 600, 40)
	make(null, TestWorld.map(4000.0, [ledge], Vector2(560, TestWorld.FLOOR_Y - 400)))
	for i in ticks(2.0):
		step_with(RIGHT)
		if not toy.foot_contact:
			break
	idle(rules.jump_ground_grace + TICK * 2)
	var before := vel().y
	step_with(UP)
	assert_lt(vel().y, before + 1.0, "no jump after the grace")


# US-01.3: letting go on the ground brakes (T-9).
func test_us01_3_brake_stops_a_slow_toy_within_a_few_frames() -> void:
	make()
	toy.velocity = Vector2(rules.brake_full_below * 0.9, 0)
	var frames := 0
	while toy.speed() >= 1.0 and frames < 60:
		sim.step()
		frames += 1
	assert_lte(frames, 6, "stops within a few frames once under the brake speed")


func test_us01_3_brake_fades_out_above_its_band() -> void:
	make()
	assert_eq(ToyMotor.brake_strength(rules.brake_full_below - 1.0, rules), 1.0)
	assert_eq(ToyMotor.brake_strength(rules.brake_none_above + 1.0, rules), 0.0)
	var mid := (rules.brake_full_below + rules.brake_none_above) * 0.5
	assert_almost_eq(ToyMotor.brake_strength(mid, rules), 0.5, 0.001)


func test_us01_3_walking_toy_stops_after_letting_go() -> void:
	make()
	var t := Drills.stop_time(sim, toy)
	gut.p("stop time from full walk speed: %.3f s" % t)
	assert_lt(t, 1.0, "a walking toy stops within a second")


func test_us01_3_no_brake_with_stick_held() -> void:
	make()
	toy.velocity = Vector2(rules.brake_full_below * 0.9, 0)
	# Held at the centre: no brake, only friction and drag.
	step_with(Vector2.ZERO, true)
	assert_gt(toy.speed(), 1.0)


# US-01.4 and US-01.5: crouch past the start threshold, keep past the hold threshold, stand up
# after the delay.
func test_us01_4_crouch_and_hold() -> void:
	make()
	step_with(Vector2(0, -(rules.crouch_start_down + 0.01)))
	assert_true(toy.crouched, "crouches past the start threshold")
	var between := -(rules.crouch_hold_down + rules.crouch_start_down) * 0.5
	hold(Vector2(0, between), 1.0)
	assert_true(toy.crouched, "stays crouched past the hold threshold")


func test_us01_4_no_crouch_between_thresholds_from_standing() -> void:
	make()
	var between := -(rules.crouch_hold_down + rules.crouch_start_down) * 0.5
	hold(Vector2(0, between), 0.5)
	assert_false(toy.crouched, "the hold threshold alone does not start a crouch")


func test_us01_4_no_crouch_in_the_air() -> void:
	make()
	step_with(UP)
	idle(0.1)
	step_with(DOWN)
	assert_false(toy.crouched)


func test_us01_5_stands_up_after_the_delay() -> void:
	make()
	hold(DOWN, 0.5)
	assert_true(toy.crouched)
	var released := 0
	while toy.crouched and released < 120:
		sim.step()
		released += 1
	assert_almost_eq(released * TICK, rules.stand_up_delay, TICK * 1.5, "stands up after the stand-up delay")


# US-01.6: a crouched toy uses the crouch hitbox.
func test_us01_6_crouch_hitbox() -> void:
	make()
	var standing := toy.hit_bounds()
	var names_standing := toy.hit_shapes().map(func(s: CollisionShape2D) -> String: return s.name)
	hold(DOWN, 0.3)
	var crouched := toy.hit_bounds()
	var names_crouched := toy.hit_shapes().map(func(s: CollisionShape2D) -> String: return s.name)
	assert_eq(names_standing, ["Body", "Head"])
	assert_eq(names_crouched, ["Body", "Crouch"])
	assert_almost_eq(crouched.size.y, rules.crouch_top - rules.body_bottom, 0.01, "crouched height: feet to crouch box top")
	assert_almost_eq(standing.size.y, rules.head_height + rules.head_radius - rules.body_bottom, 0.01, "standing height: feet to head top")
	assert_almost_eq(crouched.end.y, standing.end.y, 0.01, "feet stay put")


# US-01.7: no damage from falls or landings.
func test_us01_7_no_fall_damage() -> void:
	make()
	toy.position.y -= 4000.0
	toy.velocity = Vector2(0, rules.top_speed)
	var max_hp := toy.health
	idle(10.0)
	assert_true(toy.foot_contact, "landed")
	assert_eq(toy.health, max_hp, "no damage from a fall at top speed")


# US-01.8: walk speed, fly speed and both catch-up rates scale with the weight factor.
func test_us01_8_weight_factor_formula() -> void:
	make()
	assert_eq(toy.weight_factor(rules), 1.0, "bare hands weigh 1")
	toy.weapon_weights = PackedFloat32Array([0.7])
	assert_almost_eq(toy.weight_factor(rules), 0.7, 0.0001, "primary counts fully")
	toy.weapon_weights = PackedFloat32Array([0.9, 0.8])
	var share := rules.offhand_weight_share
	assert_almost_eq(toy.weight_factor(rules), 0.9 * (0.8 * (1.0 - share) + share), 0.0001, "off hand counts by the share")


func test_us01_8_weight_scales_targets_and_rates() -> void:
	make()
	var w := 0.7
	assert_almost_eq(ToyMotor.walk_target(1.0, rules, w), rules.walk_speed * w, 0.0001)
	assert_almost_eq(ToyMotor.walk_rate(rules, w), rules.walk_catch_up * w, 0.0001)
	assert_almost_eq(ToyMotor.fly_target(rules, w), rules.fly_speed * w, 0.0001)
	assert_almost_eq(ToyMotor.fly_rate(1.0, rules, w), rules.fly_catch_up * w, 0.0001)


func test_us01_8_heavy_toy_walks_and_flies_slower() -> void:
	make()
	var light_walk := Drills.top_walk_speed(sim, toy, 3.0)
	make()
	toy.weapon_weights = PackedFloat32Array([0.7])
	var heavy_walk := Drills.top_walk_speed(sim, toy, 3.0)
	assert_lt(heavy_walk, light_walk * 0.8, "the minigun's weight slows walking")
	# Flying sideways for a second from a hover.
	make()
	take_off()
	hold(RIGHT, 1.0)
	var light_fly := vel().x
	make()
	toy.weapon_weights = PackedFloat32Array([0.7])
	take_off()
	hold(RIGHT, 1.0)
	assert_lt(vel().x, light_fly * 0.8, "and flying")
