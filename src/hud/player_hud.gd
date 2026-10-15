class_name PlayerHud
extends Node
## The player's screen furniture: the HUD and the touch controls, wired to the camera. The view
## that runs the match adds one, hands every tick's intent to `on_intent` (the aim the camera
## looks along) and calls `frame` once per drawn frame.
##
## The sim owns the zoom: a zoom tap goes to it as a button in the intent, and each frame the
## camera eases to the player's `Fighter.zoom_level` and looks ahead by the held weapon's factor.

var sim: MatchSim
var toy_id: int = 0
var camera: GameCamera
var settings: ControlSettings
var view_rules: ViewRules
var hud: Hud
var touch: TouchControls
var layer: CanvasLayer
var source: SimHudSource


## `camera` is the match camera; its settings are shared with the touch controls.
func setup(match_sim: MatchSim, player_toy: int, game_camera: GameCamera) -> void:
	sim = match_sim
	toy_id = player_toy
	camera = game_camera
	settings = camera.rig.settings
	view_rules = camera.rig.rules
	layer = CanvasLayer.new()
	layer.name = "HudLayer"
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	hud.name = "Hud"
	source = SimHudSource.new(sim, toy_id)
	hud.setup(source, view_rules)
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch = TouchControls.new()
	touch.name = "TouchControls"
	layer.add_child(touch)
	touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch.setup(view_rules, settings)
	touch.always_show = DisplayServer.is_touchscreen_available()
	settings.apply_audio()
	if sim.combat != null:
		sim.combat.event.connect(_on_combat_event)
	_send_zoom_mode()
	_sync_held()


## Every tick's intent for the player, whatever produced it.
func on_intent(intent: InputIntent) -> void:
	camera.rig.set_aim(intent.aim)


## Re-reads the settings into the controls (after the settings screen).
func apply_settings() -> void:
	touch.apply_settings()
	settings.apply_audio()
	_send_zoom_mode()


## One drawn frame, after the camera moved.
func frame() -> void:
	_sync_held()
	hud.view_rect = camera.view_rect()
	touch.zoom_label = "%dX" % camera.rig.level
	touch.can_pick_up = hud.state.can_pick_up


func _fighter() -> Fighter:
	return sim.combat.fighter(toy_id) if sim.combat != null else null


## The camera follows the sim's zoom level and the held weapon's look-ahead (US-10, T-81).
func _sync_held() -> void:
	var f := _fighter()
	if f == null:
		return
	var w := f.main_weapon()
	camera.rig.set_held(f.zoom_level, w.def.look_ahead if w != null else -1.0)


## US-10.4: the zoom mode is the player's setting, sent to the match like a join option.
func _send_zoom_mode() -> void:
	var f := _fighter()
	if f != null:
		sim.combat.set_zoom_mode(f, int(settings.zoom_mode) as Fighter.ZoomMode)


## T-63: blasts within their reach shake this player's screen.
func _on_combat_event(e: Dictionary) -> void:
	if e.type != &"blast":
		return
	var me := sim.toy(toy_id)
	if me != null:
		camera.rig.blast(me.position.distance_to(e.pos), float(e.power), float(e.shake_reach))
