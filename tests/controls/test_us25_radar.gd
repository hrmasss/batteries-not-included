extends GutTest
## US-25.3: edge arrows for off-screen toys that fire or move fast nearby (T-87), enemies and
## teammates apart.

const DT := 1.0 / 60.0
const VIEW := Rect2(-320, -180, 640, 360)

var view_rules: ViewRules


func before_each() -> void:
	view_rules = ViewRules.from_ruleset(TestWorld.rules())


func _contact(id: int, pos: Vector2, vel: Vector2 = Vector2.ZERO, team: int = 1, fired: bool = false) -> HudState.Contact:
	var c := HudState.Contact.new()
	c.toy_id = id
	c.position = pos
	c.velocity = vel
	c.team = team
	c.fired = fired
	return c


func _run(radar: Radar, contacts: Array[HudState.Contact], seconds: float, my_team: int = 0) -> void:
	for i in roundi(seconds / DT):
		radar.step(DT, Vector2.ZERO, VIEW, my_team, contacts)


func test_fast_offscreen_toy_in_range_gets_an_arrow() -> void:
	var r := Radar.new(view_rules)
	var fast := view_rules.radar_speed + 10.0
	_run(r, [_contact(2, Vector2(900, 0), Vector2(fast, 0))], 0.2)
	assert_eq(r.visible().size(), 1)
	assert_almost_eq(r.visible()[0].dir.x, 1.0, 1e-4, "points at it")


func test_slow_quiet_toy_gets_none() -> void:
	var r := Radar.new(view_rules)
	_run(r, [_contact(2, Vector2(900, 0), Vector2(view_rules.radar_speed - 10.0, 0))], 0.5)
	assert_eq(r.visible().size(), 0)


func test_firing_toy_gets_one() -> void:
	var r := Radar.new(view_rules)
	var c := _contact(2, Vector2(0, -800), Vector2.ZERO, 1, true)
	r.step(DT, Vector2.ZERO, VIEW, 0, [c])
	assert_eq(r.visible().size(), 1)
	assert_almost_eq(r.visible()[0].dir.y, -1.0, 1e-4)


func test_out_of_range_gets_none() -> void:
	var r := Radar.new(view_rules)
	_run(r, [_contact(2, Vector2(view_rules.radar_range + 50.0, 0), Vector2(999, 0), 1, true)], 0.3)
	assert_eq(r.visible().size(), 0)


func test_on_screen_gets_none() -> void:
	var r := Radar.new(view_rules)
	_run(r, [_contact(2, Vector2(100, 50), Vector2(999, 0), 1, true)], 0.3)
	assert_eq(r.visible().size(), 0)


func test_just_off_screen_inside_margin_counts_as_on_screen() -> void:
	var r := Radar.new(view_rules)
	_run(r, [_contact(2, Vector2(VIEW.end.x + view_rules.radar_margin * 0.5, 0), Vector2(999, 0))], 0.3)
	assert_eq(r.visible().size(), 0)


func test_enemies_and_teammates_marked_apart() -> void:
	var r := Radar.new(view_rules)
	_run(r, [_contact(2, Vector2(900, 0), Vector2(999, 0), 1), _contact(3, Vector2(-900, 0), Vector2(999, 0), 0)], 0.2, 0)
	assert_true(r.arrows[2].enemy)
	assert_false(r.arrows[3].enemy)


func test_free_for_all_everyone_is_an_enemy() -> void:
	var r := Radar.new(view_rules)
	_run(r, [_contact(2, Vector2(900, 0), Vector2(999, 0), -1)], 0.2, -1)
	assert_true(r.arrows[2].enemy)


func test_arrow_fades_after_the_toy_goes_quiet() -> void:
	var r := Radar.new(view_rules)
	var c := _contact(2, Vector2(900, 0), Vector2(999, 0))
	_run(r, [c], 0.5)
	assert_almost_eq(r.arrows[2].alpha, Radar.MAX_ALPHA, 1e-4, "bright while it holds, capped")
	c.velocity = Vector2.ZERO
	_run(r, [c], 0.1)
	assert_lt(r.visible()[0].alpha, Radar.MAX_ALPHA)
	_run(r, [c], 1.0)
	assert_eq(r.visible().size(), 0, "gone once faded")


func test_dead_toys_get_no_arrow() -> void:
	var r := Radar.new(view_rules)
	var c := _contact(2, Vector2(900, 0), Vector2(999, 0))
	c.alive = false
	_run(r, [c], 0.3)
	assert_eq(r.visible().size(), 0)
