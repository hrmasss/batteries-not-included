extends CombatTest
## US-10 with the sim owning the zoom: the player's zoom mode (US-10.4) decides the level on a
## weapon change, the camera eases to `Fighter.zoom_level`, and each weapon row carries its
## look-ahead factor (T-81) for the camera.

## The classic's per-gun look-ahead for the launch weapons (T-81; recon controls-hud-camera.md).
const CLASSIC_LOOK_AHEAD := {
	&"pistol": 0.25, &"uzi": 0.375, &"smg": 0.4, &"assault_rifle": 0.45,
	&"pump_shotgun": 0.45, &"sniper_rifle": 0.7, &"rocket_launcher": 0.65,
}


func test_t81_every_weapon_row_has_the_classic_look_ahead() -> void:
	make()
	for id: StringName in rules.weapons.ids():
		assert_true(CLASSIC_LOOK_AHEAD.has(id), "%s has a classic look-ahead to check against" % id)
		assert_almost_eq(weapon(id).look_ahead, float(CLASSIC_LOOK_AHEAD.get(id, -1.0)), 1e-6, "%s look-ahead" % id)


func test_t81_look_ahead_is_checked_like_any_weapon_value() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RulesetLoader.STANDARD_DIR.path_join(WeaponTable.FILE))
	cfg.erase_section_key("uzi", "look_ahead")
	cfg.set_value("smg", "look_ahead", 5.0)
	var r := WeaponTable.from_config(cfg)
	assert_false(r.ok())
	var all := "\n".join(r.errors)
	assert_string_contains(all, "weapons.uzi.look_ahead (T-50): missing")
	assert_string_contains(all, "weapons.smg.look_ahead")


func test_us10_4_widest_takes_the_weapons_widest_level() -> void:
	make()
	var me := add(400)
	combat.set_zoom_mode(me, Fighter.ZoomMode.WIDEST)
	arm(me, &"pistol", &"sniper_rifle")
	press(me, InputIntent.Act.SWITCH)
	assert_eq(me.zoom_level, 7, "sniper: widest is 7X")
	press(me, InputIntent.Act.SWITCH)
	assert_eq(me.zoom_level, 2, "pistol: widest is 2X")


func test_us10_4_keep_stays_at_or_below_the_level_now() -> void:
	make()
	var me := add(400)
	combat.set_zoom_mode(me, Fighter.ZoomMode.KEEP)
	arm(me, &"sniper_rifle", &"assault_rifle")
	press(me, InputIntent.Act.ZOOM)
	press(me, InputIntent.Act.ZOOM)
	assert_eq(me.zoom_level, 5)
	press(me, InputIntent.Act.SWITCH)
	assert_eq(me.zoom_level, 4, "rifle: highest allowed at or below 5X")
	press(me, InputIntent.Act.ZOOM)
	press(me, InputIntent.Act.SWITCH)
	assert_eq(me.zoom_level, 1, "sniper from 1X keeps 1X, not its last 5X")


func test_us10_4_the_settings_choice_reaches_the_sim() -> void:
	assert_eq(ControlSettings.ZoomMode.keys(), Fighter.ZoomMode.keys(), "same choices in the same order")
	make()
	var me := add(400)
	var settings := ControlSettings.new()
	settings.zoom_mode = ControlSettings.ZoomMode.WIDEST
	var hud := _player_hud(me, settings)
	assert_eq(me.zoom_mode, Fighter.ZoomMode.WIDEST)
	settings.zoom_mode = ControlSettings.ZoomMode.KEEP
	hud.apply_settings()
	assert_eq(me.zoom_mode, Fighter.ZoomMode.KEEP)


func test_us10_2_camera_follows_the_sims_zoom_and_weapon() -> void:
	make()
	var me := add(400)
	arm(me, &"sniper_rifle")
	var hud := _player_hud(me, ControlSettings.new())
	var rig := hud.camera.rig
	press(me, InputIntent.Act.ZOOM)
	hud.frame()
	assert_eq(rig.level, 3, "the camera's level is the fighter's")
	assert_eq(rig.level, me.zoom_level)
	assert_almost_eq(rig.weapon_factor, weapon(&"sniper_rifle").look_ahead, 1e-6, "look-ahead from the weapon row")
	rig.step(1.0 / 60.0)
	assert_gt(rig.scale, rules.zoom_scale_3, "eases toward the new level (T-83)")
	assert_eq(hud.touch.zoom_label, "3X")
	arm(me, &"pistol")
	hud.frame()
	assert_almost_eq(rig.weapon_factor, weapon(&"pistol").look_ahead, 1e-6)


func test_t81_bare_hands_use_the_bare_factor() -> void:
	make()
	var me := add(400)
	me.weapons.clear()
	var hud := _player_hud(me, ControlSettings.new())
	hud.frame()
	assert_eq(hud.camera.rig.level, 1)
	assert_almost_eq(hud.camera.rig.weapon_factor, maxf(rules.look_ahead_bare, rules.look_ahead_floor), 1e-6)


func _player_hud(me: Fighter, settings: ControlSettings) -> PlayerHud:
	var cam := GameCamera.new(rules, settings)
	add_child_autofree(cam)
	var hud := PlayerHud.new()
	add_child_autofree(hud)
	hud.setup(sim, me.id(), cam)
	return hud
