extends CombatTest
## US-06: bullets that feel fair. Sim checks.


func _first_hit(seconds: float = 1.0) -> Dictionary:
	for k in ticks(seconds):
		step()
		var hits := events_of(&"hit")
		if not hits.is_empty():
			return hits[0]
	return {}


# US-06.1: bullet speed plus a share of the shooter's velocity.
func test_us06_1_bullet_speed_inherits_shooter_velocity() -> void:
	make()
	var me := add(400)
	weapon(&"pistol").spread = 0.0
	me.toy.velocity = Vector2(100, 0)
	set_intent(me, AIM_UP, true)
	step()
	var b: CombatSim.Bullet = combat.bullets.back()
	var shooter_v := me.toy.velocity
	assert_almost_eq(b.vel.y, -weapon(&"pistol").bullet_speed + shooter_v.y * rules.inherit_velocity, 1.0, "aim speed up")
	assert_almost_eq(b.vel.x, shooter_v.x * rules.inherit_velocity, 1.0, "inherits 0.8 of the sideways speed")


func test_us06_1_bullet_stops_at_a_wall() -> void:
	make([Rect2(550, FLOOR - 200, 20, 200)])
	var me := add(400)
	var you := add(600)
	weapon(&"pistol").spread = 0.0
	set_intent(me, AIM_RIGHT, true)
	run(1.0)
	assert_eq(you.toy.health, rules.max_health, "the wall took every bullet")


func test_us06_1_bullet_stops_at_the_first_toy() -> void:
	make()
	var me := add(400)
	var near := add(500)
	var far := add(600)
	weapon(&"pistol").spread = 0.0
	set_intent(me, AIM_RIGHT, true)
	run(0.5)
	assert_lt(near.toy.health, rules.max_health, "the first toy is hit")
	assert_eq(far.toy.health, rules.max_health, "the one behind is not")


func test_us06_1_bullet_never_passes_its_range() -> void:
	make()
	var me := add(400)
	var d := weapon(&"pistol")
	var you := add(400 + d.range + 20)
	d.spread = 0.0
	set_intent(me, AIM_RIGHT, true)
	run(1.0)
	assert_eq(you.toy.health, rules.max_health, "out of range")
	for b in combat.bullets:
		assert_lte(b.travelled, d.range)


# US-06.2: full damage to half range, then down to half at max range (T-41).
func test_us06_2_falloff_by_distance() -> void:
	var d_near := 0.0
	var d_far := 0.0
	for gap in [150.0, 400.0]:
		make()
		var me := add(400)
		var you := add(400 + gap)
		weapon(&"pistol").spread = 0.0
		set_intent(me, AIM_RIGHT, true)
		var hit := _first_hit()
		if gap < 200.0:
			d_near = hit.amount
		else:
			d_far = hit.amount
	var d := weapon(&"pistol")
	assert_almost_eq(d_near, d.damage, 0.001, "full damage inside half range")
	# The bullet hits the body's near edge, half a body width short of the gap.
	var travelled := 400.0 - rules.body_width * 0.5
	var start := d.range * rules.falloff_start_share
	assert_almost_eq(d_far, d.damage * (1.0 - (travelled - start) / d.range), 0.2, "falls off past half range")
	assert_almost_eq(combat.falloff(d.range, d.range), 0.5, 0.0001, "half at max range")


# US-06.3: a head hit on a standing toy does the headshot factor; never on a crouched one.
func test_us06_3_headshot_multiplies() -> void:
	# The shooter stands on a ledge so its bullets fly at the target's head height.
	make([Rect2(300, FLOOR - rules.head_height, 200, rules.head_height)])
	var me := add(400, Fighter.NO_TEAM, false, FLOOR - rules.head_height)
	var you := add(600)
	weapon(&"pistol").spread = 0.0
	set_intent(me, AIM_RIGHT, true)
	var hit := _first_hit()
	assert_true(hit.head, "hit the head")
	assert_almost_eq(hit.amount, weapon(&"pistol").damage * rules.headshot_factor, 0.001)


func test_us06_3_no_headshot_on_a_crouched_toy() -> void:
	make([Rect2(300, FLOOR - rules.head_height, 200, rules.head_height)])
	var me := add(400, Fighter.NO_TEAM, false, FLOOR - rules.head_height)
	var you := add(600)
	weapon(&"pistol").spread = 0.0
	set_intent(you, AIM_LEFT, false, 0, Vector2(0, -1))
	run(0.3)
	assert_true(you.toy.crouched, "crouched")
	# Aim down a little into the crouch box.
	var drop := rules.head_height - (rules.crouch_top + rules.crouch_bottom) * 0.5
	set_intent(me, Vector2(200, -drop).normalized(), true)
	var hit := _first_hit()
	assert_false(hit.is_empty(), "the crouched toy is hit")
	assert_false(hit.head, "no head to hit")
	assert_almost_eq(hit.amount, weapon(&"pistol").damage, 0.001, "no headshot factor")


# US-06.4: bullets and melee pass through teammates without effect.
func test_us06_4_bullets_pass_through_teammates() -> void:
	make()
	var me := add(400, 2)
	var mate := add(500, 2)
	var enemy := add(600, 3)
	weapon(&"pistol").spread = 0.0
	set_intent(me, AIM_RIGHT, true)
	run(0.5)
	assert_eq(mate.toy.health, rules.max_health, "teammate untouched")
	assert_lt(enemy.toy.health, rules.max_health, "the enemy behind is hit")


func test_us06_4_free_for_all_hits_everyone() -> void:
	make()
	var me := add(400)
	var other := add(500)
	weapon(&"pistol").spread = 0.0
	set_intent(me, AIM_RIGHT, true)
	run(0.3)
	assert_lt(other.toy.health, rules.max_health, "no teams: everyone is an enemy")


# US-06.5: knockback in proportion to the damage (T-33), capped per axis.
func test_us06_5_knockback_follows_damage() -> void:
	for id: StringName in [&"pistol", &"sniper_rifle"]:
		make()
		var me := add(400)
		var you := add(600)
		arm(me, id)
		weapon(id).spread = 0.0
		set_intent(me, AIM_RIGHT, true)
		var hit := {}
		for k in ticks(0.5):
			var before := you.toy.velocity
			step()
			var hits := events_of(&"hit")
			if not hits.is_empty():
				hit = hits[0]
				var expect := minf(float(hit.amount) * rules.knockback_per_hp, rules.knockback_cap)
				assert_almost_eq(you.toy.velocity.x - before.x, expect, 0.01, "%s pushes by its damage" % id)
				break
		assert_false(hit.is_empty(), "%s hit" % id)


# US-34.3 (sim side): damage comes from the ruleset; the intent carries no numbers.
func test_us34_3_damage_comes_from_the_ruleset() -> void:
	make(Array(), func(r: Ruleset) -> void: r.weapons.get_def(&"pistol").damage = 33.0)
	var me := add(400)
	var you := add(500)
	weapon(&"pistol").spread = 0.0
	set_intent(me, AIM_RIGHT, true)
	assert_almost_eq(_first_hit().amount, 33.0, 0.001)
