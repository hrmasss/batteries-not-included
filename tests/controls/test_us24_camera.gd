extends GutTest
## US-24.1 (anchor), US-24.2 (look-ahead by weapon, easing at panning speed), US-24.3 (same world
## area on every screen shape), US-10.1 and US-10.3 (zoom levels per weapon, memory), T-83.

const CANVAS_H := 360.0
const DT := 1.0 / 60.0

var view_rules: ViewRules
var settings: ControlSettings


func before_each() -> void:
	view_rules = ViewRules.from_ruleset(TestWorld.rules())
	settings = ControlSettings.new()


func _rig() -> CameraRig:
	return CameraRig.new(view_rules, settings)


func test_us24_1_toy_sits_at_the_anchor() -> void:
	var rig := _rig()
	var body := Vector2(1234, 567)
	for aspect: float in [16.0 / 9.0, 2400.0 / 1080.0, 4.0 / 3.0]:
		var center := rig.center_for(body, aspect, CANVAS_H)
		var view := rig.visible_world(aspect)
		# Body's place on screen in canvas points from the middle, y down.
		var points := (body - center) / view.y * CANVAS_H
		assert_almost_eq(points.x, 0.0, 1e-3, "centred across, aspect %s" % aspect)
		assert_almost_eq(points.y, view_rules.anchor_below_middle, 1e-3, "T-84 below middle, aspect %s" % aspect)


func test_us24_1_hard_follow_has_no_lag() -> void:
	var rig := _rig()
	var a := rig.center_for(Vector2(0, 0), 16.0 / 9.0, CANVAS_H)
	rig.step(DT)
	var b := rig.center_for(Vector2(300, -40), 16.0 / 9.0, CANVAS_H)
	assert_almost_eq((b - a).x, 300.0, 1e-3)
	assert_almost_eq((b - a).y, -40.0, 1e-3)


func test_us24_2_look_ahead_settles_on_weapon_factor() -> void:
	var rig := _rig()
	var w := WeaponView.for_weapon(&"sniper_rifle")
	rig.set_weapon(w.key, w.zoom_levels, w.look_ahead)
	rig.set_aim(Vector2(1, 0))
	for i in 60 * 10:
		rig.step(DT)
	var aspect := 16.0 / 9.0
	var view := rig.visible_world(aspect)
	var shift := rig.center_for(Vector2.ZERO, aspect, CANVAS_H) + Vector2(0, view_rules.anchor_below_middle * view.y / CANVAS_H)
	assert_almost_eq(shift.x, view.x * 0.25 * view_rules.look_ahead * w.look_ahead, 0.01, "T-81 (W/4) × share × factor")
	assert_almost_eq(shift.y, 0.0, 0.01)


func test_us24_2_look_ahead_eases_at_panning_speed() -> void:
	var rig := _rig()
	rig.set_weapon(&"pistol", [1, 2], 0.25)
	rig.set_aim(Vector2(0, 1))
	var target := -view_rules.look_ahead * 0.25
	rig.step(DT)
	var expect := target * DT * view_rules.panning_speed
	assert_almost_eq(rig.look.y, expect, 1e-6, "first frame closes dt × speed of the gap")
	var t := DT
	while t < 1.0:
		rig.step(DT)
		t += DT
	assert_lt(absf(rig.look.y), absf(target), "still easing after a second")
	assert_gt(absf(rig.look.y), absf(target) * 0.7, "most of the way after a second at 1.5/s")


func test_us24_2_bigger_factor_looks_further() -> void:
	var near := _rig()
	near.set_weapon(&"pistol", [1, 2], 0.25)
	var far := _rig()
	far.set_weapon(&"sniper_rifle", [1, 3, 5, 7], 0.7)
	for r: CameraRig in [near, far]:
		r.set_aim(Vector2(1, 0))
		for i in 600:
			r.step(DT)
	assert_gt(far.look.x, near.look.x * 2.0)


func test_t81_factor_floor_applies() -> void:
	var rig := _rig()
	rig.set_weapon(&"odd", [1], 0.01)
	assert_almost_eq(rig.weapon_factor, view_rules.look_ahead_floor, 1e-6)
	rig.set_weapon(&"", [1], -1.0)
	assert_almost_eq(rig.weapon_factor, maxf(view_rules.look_ahead_bare, view_rules.look_ahead_floor), 1e-6)


func test_us24_3_same_world_area_on_every_screen_shape() -> void:
	var rig := _rig()
	var base := rig.visible_world(16.0 / 9.0)
	var area := base.x * base.y
	assert_almost_eq(base.y, view_rules.view_height, 1e-3, "16:9 sees the view height")
	for size: Vector2 in [Vector2(1280, 720), Vector2(2400, 1080), Vector2(2340, 1080), Vector2(2048, 1536), Vector2(1920, 1200)]:
		var v := rig.visible_world(size.x / size.y)
		assert_almost_eq(v.x * v.y, area, area * 1e-5, "area at %s" % size)
		assert_almost_eq(v.x / v.y, size.x / size.y, 1e-4, "shape at %s" % size)


func test_us10_1_zoom_steps_only_through_allowed_levels() -> void:
	var rig := _rig()
	rig.set_weapon(&"assault_rifle", [1, 2, 4], 0.45)
	var seen := []
	for i in 6:
		rig.zoom_tap()
		seen.append(rig.level)
	assert_eq(seen, [2, 4, 1, 2, 4, 1])


func test_t80_zoom_scale_eases_to_the_ladder_value() -> void:
	var rig := _rig()
	rig.set_weapon(&"sniper_rifle", [1, 3, 5, 7], 0.7)
	rig.zoom_tap()
	rig.zoom_tap()
	assert_eq(rig.level, 5)
	rig.step(DT)
	assert_gt(rig.scale, view_rules.scale_for(5), "eases, not snaps")
	for i in 120:
		rig.step(DT)
	assert_almost_eq(rig.scale, view_rules.scale_for(5), 1e-3)
	var v1 := _rig().visible_world(16.0 / 9.0)
	var v5 := rig.visible_world(16.0 / 9.0)
	assert_almost_eq(v5.y, v1.y / view_rules.scale_for(5), 0.5, "lower scale shows more map")


func test_t83_zoom_speed_zero_snaps() -> void:
	settings.zoom_speed = 0.0
	var rig := _rig()
	rig.set_weapon(&"sniper_rifle", [1, 3, 5, 7], 0.7)
	rig.zoom_tap()
	rig.step(DT)
	assert_almost_eq(rig.scale, view_rules.scale_for(3), 1e-6)


func test_us10_3_weapon_change_returns_to_last_used_level() -> void:
	var rig := _rig()
	rig.set_weapon(&"sniper_rifle", [1, 3, 5, 7], 0.7)
	rig.zoom_tap()
	rig.zoom_tap()
	assert_eq(rig.level, 5)
	rig.set_weapon(&"pistol", [1, 2], 0.25)
	assert_eq(rig.level, 2, "no memory: nearest allowed to 5 is 2")
	rig.zoom_tap()
	assert_eq(rig.level, 1)
	rig.set_weapon(&"sniper_rifle", [1, 3, 5, 7], 0.7)
	assert_eq(rig.level, 5, "back to the sniper's last level")
	rig.set_weapon(&"pistol", [1, 2], 0.25)
	assert_eq(rig.level, 1, "back to the pistol's last level")


func test_us10_4_zoom_modes() -> void:
	settings.zoom_mode = ControlSettings.ZoomMode.WIDEST
	var rig := _rig()
	rig.set_weapon(&"sniper_rifle", [1, 3, 5, 7], 0.7)
	assert_eq(rig.level, 7)
	settings.zoom_mode = ControlSettings.ZoomMode.KEEP
	rig.set_weapon(&"assault_rifle", [1, 2, 4], 0.45)
	assert_eq(rig.level, 4, "keep: nearest allowed at or below")


func test_us24_4_blast_shakes_by_distance_and_setting() -> void:
	var rig := _rig()
	rig.blast(10.0, 1.0)
	var close := rig.shake
	var rig2 := _rig()
	rig2.blast(120.0, 1.0)
	assert_gt(close, rig2.shake, "nearer shakes harder")
	var rig3 := _rig()
	rig3.blast(view_rules.shake_reach + 1.0, 1.0)
	assert_eq(rig3.shake, 0.0, "out of reach, no shake")
	settings.shake = 0.0
	var rig4 := _rig()
	rig4.blast(10.0, 1.0)
	rig4.step(DT)
	var a := rig4.center_for(Vector2.ZERO, 16.0 / 9.0, CANVAS_H)
	var calm := _rig().center_for(Vector2.ZERO, 16.0 / 9.0, CANVAS_H)
	assert_almost_eq(a.distance_to(calm), 0.0, 1e-4, "US-24.5: shake off means no shake")
