extends CombatTest
## US-25 on real combat state: the HUD source reads the weapon, ammo, grenades, scores, pops,
## kill feed, hits and radar alerts from `CombatSim`, not from stand-ins.

var source: SimHudSource
var state: HudState


func _hud(me: Fighter) -> void:
	source = SimHudSource.new(sim, me.id())
	source.names = {me.id(): "Sarge"}
	state = HudState.new()


func _read() -> void:
	source.read(state, TICK)


func test_us25_ammo_and_weapon_from_the_held_gun() -> void:
	make()
	var me := add(400)
	_hud(me)
	arm(me, &"uzi")
	set_intent(me, AIM_RIGHT, true)
	run(0.35)
	_read()
	var w := me.main_weapon()
	assert_lt(w.mag, weapon(&"uzi").mag, "the uzi fired")
	assert_eq(state.magazine, w.mag)
	assert_eq(state.reserve, w.reserve)
	assert_eq(state.weapon_name, weapon(&"uzi").display_name)
	assert_false(state.ammo_infinite)


func test_us25_grenades_by_type_with_counts() -> void:
	make()
	var me := add(400)
	_hud(me)
	_read()
	assert_eq(state.grenades.size(), 1)
	assert_eq(state.grenades[0].kind, me.grenade_type)
	assert_eq(state.grenades[0].count, me.grenade_count())


func test_us25_pop_fills_the_feed_and_the_respawn_panel() -> void:
	make()
	var me := add(400, 1)
	var you := add(900, 2)
	_hud(me)
	source.names[you.id()] = "Plushie"
	combat.hurt(me, 1000.0, you.id(), &"uzi", CombatSim.Hurt.BULLET)
	_read()
	assert_eq(state.feed.size(), 1)
	assert_eq(state.feed[0].killer, "Plushie")
	assert_eq(state.feed[0].killer_team, 1, "team 2 is the HUD's second team")
	assert_eq(state.feed[0].victim, "Sarge")
	assert_eq(state.feed[0].victim_team, 0)
	assert_true(state.popped)
	assert_eq(state.popped_by, "Plushie")
	assert_eq(state.popped_with, "the %s" % weapon(&"uzi").display_name)
	assert_almost_eq(state.respawn_in, rules.respawn_wait, TICK)
	assert_eq(state.scores.size(), 2, "two team chips")
	assert_eq(state.scores[1].kills, 1, "the other team scored")


func test_us25_feed_lines_age_out() -> void:
	make()
	var me := add(400)
	var you := add(900)
	_hud(me)
	combat.hurt(you, 1000.0, me.id(), &"pistol", CombatSim.Hurt.BULLET)
	_read()
	assert_eq(state.feed.size(), 1)
	assert_true(state.team_mode == false)
	assert_eq(state.scores[0].kills, 1, "free-for-all: my kills first")
	source.read(state, HudState.FEED_LIFE)
	assert_eq(state.feed.size(), 0)


func test_us25_4_hit_points_back_at_the_shooter() -> void:
	make()
	var me := add(400)
	var you := add(700)
	_hud(me)
	set_intent(you, AIM_LEFT, true)
	run_until(func() -> bool: return me.toy.health < rules.max_health, 1.0)
	_read()
	assert_gt(state.hits_from.size(), 0, "a hit landed")
	assert_almost_eq(state.hits_from[0].x, you.toy.position.x, 1.0, "from the shooter's side")
	_read()
	assert_eq(state.hits_from.size(), 0, "each hit shows once")


func test_us25_3_shots_light_the_radar() -> void:
	make()
	var me := add(400)
	var you := add(2400)
	_hud(me)
	set_intent(you, AIM_RIGHT, true)
	step()
	_read()
	var c: HudState.Contact = state.contacts[0]
	assert_eq(c.toy_id, you.id())
	assert_true(c.fired, "fired since the last read")
	set_intent(you, AIM_RIGHT, false)
	step()
	_read()
	assert_false(state.contacts[0].fired)


func test_us07_3_pick_up_shows_when_a_weapon_is_in_reach() -> void:
	make()
	var me := add(400)
	_hud(me)
	_read()
	assert_false(state.can_pick_up)
	combat.place_item(&"smg", me.toy.position)
	run(0.3)
	_read()
	assert_true(state.can_pick_up)
