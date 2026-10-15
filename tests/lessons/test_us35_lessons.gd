extends CombatTest
## US-35.1 and US-35.2: the lessons come in order, and each moves on only when the player has
## done what it teaches, naming the control to use.

var me: Fighter
var lesson: LessonRunner


func _start(id: StringName, rects: Array = []) -> void:
	make(rects)
	me = add(1000)
	lesson = LessonRunner.new(sim, me, func(team: int, feet: Vector2) -> Fighter:
		var f := combat.join(sim.spawn_toy(0, &"plastic_soldier", feet), team, false)
		set_intent(f, AIM_LEFT)
		return f)
	lesson.start(id)


## Runs `seconds` with the player's intent, feeding the lesson each tick.
func _play(seconds: float, until_step: int = -1) -> void:
	for k in ticks(seconds):
		step()
		lesson.on_tick(intents[me.id()])
		if lesson.done or (until_step >= 0 and lesson.index >= until_step):
			return


## Presses `button` for one tick and lets go, feeding the lesson both ticks.
func _tap(button: InputIntent.Act) -> void:
	(intents[me.id()] as InputIntent).set_button(button, true)
	_play(SimClock.TICK)
	(intents[me.id()] as InputIntent).set_button(button, false)
	_play(SimClock.TICK)


func test_us35_1_lessons_in_order() -> void:
	# The first set: move, fly, aim and fire, pick up, grenade (the spec's order, short).
	assert_eq(LessonRunner.LESSONS, [&"move", &"fly", &"aim_fire", &"pick_up", &"grenade"] as Array[StringName])
	assert_eq(LessonRunner.next_of(&"move"), &"fly")
	assert_eq(LessonRunner.next_of(&"grenade"), &"")


func test_us35_2_every_step_points_at_a_control() -> void:
	make()
	me = add(1000)
	for id in LessonRunner.LESSONS:
		var l := LessonRunner.new(sim, me, Callable())
		for s in l._steps(id):
			assert_true(LessonScreen.CONTROLS.has(s.control), "%s: '%s' points at a known control" % [id, s.text])
			assert_ne(s.keys, "", "%s has a desktop hint" % id)


func test_us35_2_move_waits_for_walking_jumping_crouching() -> void:
	_start(&"move")
	_play(2.0)
	assert_eq(lesson.index, 0, "standing still does not count")
	set_intent(me, AIM_RIGHT, false, 0, Vector2(1, 0))
	_play(5.0, 1)
	assert_eq(lesson.index, 1, "walked: on to jumping")
	set_intent(me, AIM_RIGHT, false, 0, Vector2(0, 1))
	_play(1.0, 2)
	assert_eq(lesson.index, 2, "jumped: on to crouching")
	set_intent(me)
	_play(1.5)
	assert_eq(lesson.index, 2, "landing is not a crouch")
	set_intent(me, AIM_RIGHT, false, 0, Vector2(0, -1))
	_play(1.0)
	assert_true(lesson.done, "crouched: done")


func test_us35_2_fly_waits_for_flight_and_landing() -> void:
	_start(&"fly")
	set_intent(me, AIM_RIGHT, false, 0, Vector2(0.2, 0.98))
	_play(1.0)
	assert_eq(lesson.index, 0, "a jump is not a flight yet")
	_play(3.0, 1)
	assert_eq(lesson.index, 1)
	set_intent(me, AIM_RIGHT, false, 0, Vector2(0.6, 0.8))
	_play(4.0, 2)
	assert_eq(lesson.index, 2, "flew long enough: on to landing")
	set_intent(me)
	_play(6.0)
	assert_true(lesson.done, "landed and refilled")


func test_us35_2_aim_and_fire_waits_for_the_pop() -> void:
	_start(&"aim_fire")
	_play(0.5)
	assert_eq(lesson.index, 0, "aiming takes a moment")
	_play(1.0, 1)
	assert_eq(lesson.index, 1)
	_play(0.1)
	assert_not_null(lesson.target, "a target appears")
	var dir := (lesson.target.toy.position - me.toy.position).normalized()
	set_intent(me, Vector2(dir.x, -dir.y), true)
	_play(1.0)
	assert_false(lesson.done, "hits alone are not a pop")
	_play(10.0)

	assert_true(lesson.done, "popped the target")


func test_us35_2_pick_up_waits_for_the_button_then_the_swap() -> void:
	_start(&"pick_up")
	_play(0.2)
	var gun: CombatSim.FloorItem = null
	for it in combat.items:
		if it.item == LessonRunner.GUN:
			gun = it
	assert_not_null(gun, "a gun lies on the floor")
	set_intent(me, AIM_RIGHT, false, 0, Vector2(signf(gun.pos.x - me.toy.position.x), 0))
	_play(4.0, 1)
	assert_eq(lesson.index, 1, "reached the gun")
	set_intent(me)
	_play(1.0)
	assert_eq(lesson.index, 1, "standing by it does not take it")
	_tap(InputIntent.Act.PICK_UP)
	assert_eq(lesson.index, 2, "took it")
	_tap(InputIntent.Act.SWITCH)
	assert_true(lesson.done, "swapped")


func test_us35_2_grenade_waits_for_a_blast_on_the_target() -> void:
	_start(&"grenade")
	_play(0.2)
	set_intent(me, AIM_UP)
	_tap(InputIntent.Act.GRENADE)
	assert_eq(lesson.index, 1, "threw one")
	_play(3.0)
	assert_false(lesson.done, "a frag straight up misses the target")
	# A low throw that lands a third of the way and rolls on to the target, then the blast.
	var t := lesson.target.toy.position
	var v := rules.throw_speed
	var g := rules.frag_gravity
	var dx := absf(t.x - me.toy.position.x) / 3.0
	var angle := atan((v * v - sqrt(v * v * v * v - g * g * dx * dx)) / (g * dx))
	set_intent(me, Vector2(signf(t.x - me.toy.position.x) * cos(angle), sin(angle)))
	_play(0.2)
	assert_gt(me.grenade_count() + combat.items.size(), 0, "frags restocked when out")
	_play(1.0)
	_tap(InputIntent.Act.GRENADE)
	_play(4.0)
	assert_true(lesson.done, "caught the target in a blast")


func test_lessons_on_the_bedroom_start_in_the_open_and_place_things_in_reach() -> void:
	# The art bedroom is cluttered: a lesson starts where there is floor and air, its gun lies on
	# the player's floor with nothing in the way, and its targets stand in the player's sight.
	var rules := RulesetLoader.load_standard().ruleset
	sim = MatchSim.new()
	sim.setup(rules, (load(MatchConfig.DEFAULT_MAP) as PackedScene).instantiate())
	add_child_autofree(sim)
	combat = sim.start_combat(1)
	await wait_physics_frames(1)
	me = combat.join(sim.spawn_toy(0), Fighter.NO_TEAM, false)
	lesson = LessonRunner.new(sim, me, func(team: int, feet: Vector2) -> Fighter: return combat.join(sim.spawn_toy(0, &"plastic_soldier", feet), team, false))
	var start := lesson.best_start()
	sim.place_toy(me.toy, sim.map.spawn_points()[start].global_position)
	var o := me.toy.position
	assert_gte(lesson.room_at(o, -1.0) + lesson.room_at(o, 1.0), LessonRunner.ITEM_DISTANCE * 2.0, "room to walk")
	assert_true(lesson._in_sight(o, o + Vector2(0, -LessonRunner.HEADROOM)), "air to fly")
	var gun := lesson._beside(LessonRunner.ITEM_DISTANCE, true)
	assert_almost_eq(gun.y, lesson._feet(o).y, LessonRunner.LEDGE, "the gun on the player's floor")
	assert_true(lesson._walkable(o.x, gun.x, lesson._feet(o).y), "a straight walk to it")
	for d in [LessonRunner.TARGET_DISTANCE, LessonRunner.GRENADE_TARGET_DISTANCE]:
		var feet := lesson._beside(d)
		assert_true(lesson._in_sight(o, lesson._origin(feet)), "a target %d u off is in sight" % d)
		assert_true(lesson._fits(lesson._origin(feet)), "and stands in the open")
