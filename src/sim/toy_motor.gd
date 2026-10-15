class_name ToyMotor
extends RefCounted
## Walk, jump, crouch and the jetpack: the movement rules for one toy and one tick
## (01_world "A toy", 04_tuning T-1 to T-25). Matches the classic's step order: stick and
## jetpack logic first, from the contacts the last tick found, then the physics sub-steps.
##
## Every number comes from the ruleset. The only literals allowed in this file are 0, 1 and
## the solver constants below; `tests/unit/test_rules_as_data.gd` checks that.

## The classic splits each tick into two physics steps of half the time.
const SUBSTEPS := 2
## The drive never pushes backwards: missing speed is floored at this, as in the classic.
const MIN_MISSING := 0.0001


## What the match tells a toy about the match it is in.
class Env:
	extends RefCounted
	var battery_full: float = 0.0
	var batteries_included: bool = false


## Walk target speed along the stick's sideways direction (T-3).
static func walk_target(stick_x: float, rules: Ruleset, weight: float) -> float:
	return absf(stick_x) * rules.walk_speed * weight


## Share of missing walk speed closed per second (T-4).
static func walk_rate(rules: Ruleset, weight: float) -> float:
	return rules.walk_catch_up * weight


## Fly target speed along the stick (T-5).
static func fly_target(rules: Ruleset, weight: float) -> float:
	return rules.fly_speed * weight


## Share of missing fly speed closed per second (T-6).
static func fly_rate(deflection: float, rules: Ruleset, weight: float) -> float:
	return rules.fly_catch_up * weight * deflection


## Battery drain per second for the stick's upward share (T-21).
static func drain_per_second(thrust_share: float, rules: Ruleset) -> float:
	return rules.drain_rate * thrust_share


## How hard the jetpack pushes for a stick pointing `up` (T-21): the floor share level, all of
## it straight up, never below zero.
static func thrust_share(up: float, rules: Ruleset) -> float:
	return maxf(0.0, rules.drain_floor_share + (1.0 - rules.drain_floor_share) * up)


## T-9: 1 below brake_full_below, 0 above brake_none_above, linear between.
static func brake_strength(speed: float, rules: Ruleset) -> float:
	return clampf((rules.brake_none_above - speed) / (rules.brake_none_above - rules.brake_full_below), 0.0, 1.0)


static func step(t: SimToy, intent: InputIntent, rules: Ruleset, env: Env, dt: float) -> void:
	var stick := intent.move
	var held := intent.move_held
	var up := stick.y
	var deflection := stick.length()
	var weight := t.weight_factor(rules)
	t.stick = stick
	t.stick_held = held
	if intent.aim != Vector2.ZERO:
		t.facing = intent.aim.normalized()
	elif held and stick.x != 0.0:
		t.facing = Vector2(signf(stick.x), 0.0)

	t.battery_max = env.battery_full
	if env.batteries_included:
		t.battery = env.battery_full
	t.battery = minf(t.battery, env.battery_full)
	t.since_thrust += dt

	# The thrust share uses the jetpack state from before this tick, as the classic does.
	if t.battery > 0.0 and t.jetpack_on and held:
		t.thrust = thrust_share(up, rules)
	else:
		t.thrust = 0.0

	# Engage (T-13, T-14) or land (T-15).
	if not t.foot_contact:
		t.airtime += dt
		if deflection > rules.engage_deflection and up > rules.engage_up and t.airtime > rules.engage_airtime:
			t.jetpack_on = true
	else:
		t.airtime = 0.0
		var keeps_flying := held and (up >= 0.0 or t.speed() >= rules.landing_cutoff_speed)
		if not keeps_flying:
			t.jetpack_on = false

	# Refill after the pause (T-22, T-23).
	if (not t.jetpack_on or not held) and t.since_thrust > rules.refill_pause:
		t.battery = minf(env.battery_full, t.battery + rules.refill_rate * dt)

	if not t.jetpack_on or t.battery <= 0.0:
		t.jetpack_on = false
	elif held:
		t.since_thrust = 0.0

	# Velocity in stick space (y up) while the rules work on it.
	var v := Vector2(t.velocity.x, -t.velocity.y)
	var gravity: float
	var bounce: float
	var friction: float
	if not held:
		gravity = rules.walk_gravity
		bounce = rules.toy_bounce_idle
		friction = rules.toy_friction_idle
	elif not t.jetpack_on:
		gravity = rules.walk_gravity
		bounce = rules.toy_bounce_walking
		friction = rules.toy_friction_walking
		if stick.x != 0.0:
			var dir := Vector2(signf(stick.x), 0.0)
			var missing := maxf(walk_target(stick.x, rules, weight) - v.dot(dir), MIN_MISSING)
			v += dir * (walk_rate(rules, weight) * dt * missing)
		if up > rules.jump_stick_up and t.since_foot < rules.jump_ground_grace and t.since_jump > rules.jump_cooldown:
			t.since_jump = 0.0
			v.y += rules.jump_speed
			t.thrust = 1.0
		elif t.foot_contact and ((not t.crouched and up < -rules.crouch_start_down) or (t.crouched and up < -rules.crouch_hold_down)):
			t.set_crouched(true)
			t.crouch_timer = 0.0
	else:
		gravity = rules.fly_gravity
		bounce = rules.toy_bounce_flying
		friction = rules.toy_friction_flying
		t.battery = maxf(0.0, t.battery - drain_per_second(t.thrust, rules) * dt)
		t.flight_time += dt
		if deflection > 0.0:
			var dir := stick / deflection
			var missing := maxf(fly_target(rules, weight) - v.dot(dir), MIN_MISSING)
			v += dir * (fly_rate(deflection, rules, weight) * dt * missing)

	# Stand up once the crouch has not been renewed for the stand-up delay (T-16).
	t.crouch_timer += dt
	if t.crouch_timer > rules.stand_up_delay:
		t.set_crouched(false)
		t.crouch_timer = 0.0

	if env.batteries_included:
		t.battery = env.battery_full

	t.velocity = Vector2(v.x, -v.y)
	_physics(t, held, gravity, bounce, friction, rules, dt)

	t.since_jump += dt
	t.since_foot += dt
	if t.foot_contact:
		t.since_foot = 0.0


## The classic's velocity function and contact solve, `SUBSTEPS` times per tick: keep T-7 of
## the speed per second, add gravity, cap at T-8, brake on the ground with no input (T-9).
static func _physics(t: SimToy, held: bool, gravity: float, bounce: float, friction: float, rules: Ruleset, dt: float) -> void:
	var h := dt / SUBSTEPS
	var kept := pow(rules.speed_kept_per_second, h)
	t.foot_contact = false
	for i in SUBSTEPS:
		var v := t.velocity * kept + Vector2(0.0, gravity) * h
		v = v.limit_length(rules.top_speed)
		if t.foot_contact and not held and t.thrust == 0.0:
			v -= v * minf(1.0, rules.brake_rate * h * brake_strength(v.length(), rules))
		t.velocity = v
		t.move_substep(h, bounce, friction, rules)
