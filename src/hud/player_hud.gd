class_name PlayerHud
extends Node
## The player's screen furniture: the HUD and the touch controls, wired to the camera. The view
## that runs the match adds one, hands every tick's intent to `on_intent` (zoom taps and the aim
## the camera looks along) and calls `frame` once per drawn frame.

var sim: MatchSim
var toy_id: int = 0
var camera: GameCamera
var settings: ControlSettings
var view_rules: ViewRules
var hud: Hud
var touch: TouchControls
var layer: CanvasLayer
var stub: CombatStub
var source: SimHudSource

var _prev_zoom: bool = false
var _weapon_key: StringName = &"-"


## `camera` is the match camera; its settings are shared with the touch controls.
func setup(match_sim: MatchSim, player_toy: int, game_camera: GameCamera, combat: CombatStub = null) -> void:
	sim = match_sim
	toy_id = player_toy
	camera = game_camera
	settings = camera.rig.settings
	view_rules = camera.rig.rules
	stub = combat if combat != null else CombatStub.new()
	layer = CanvasLayer.new()
	layer.name = "HudLayer"
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	hud.name = "Hud"
	source = SimHudSource.new(sim, toy_id, stub)
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
	_sync_weapon()


## Every tick's intent for the player, whatever produced it.
func on_intent(intent: InputIntent) -> void:
	var zoom := intent.is_down(InputIntent.Act.ZOOM)
	if zoom and not _prev_zoom:
		camera.rig.zoom_tap()
	_prev_zoom = zoom
	camera.rig.set_aim(intent.aim)


## Re-reads the settings into the controls (after the settings screen).
func apply_settings() -> void:
	touch.apply_settings()
	settings.apply_audio()


## One drawn frame, after the camera moved.
func frame() -> void:
	_sync_weapon()
	hud.view_rect = camera.view_rect()
	touch.zoom_label = "%dX" % camera.rig.level
	touch.can_pick_up = hud.state.can_pick_up


func _sync_weapon() -> void:
	if stub.weapon_key == _weapon_key:
		return
	_weapon_key = stub.weapon_key
	var w := WeaponView.for_weapon(_weapon_key)
	camera.rig.set_weapon(w.key, w.zoom_levels, w.look_ahead)
