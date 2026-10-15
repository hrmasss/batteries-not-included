class_name PlayerView
extends Node
## One player's window on the match: the camera, the HUD and the touch controls, plus desktop
## keyboard and mouse. The app adds one, calls `intent()` once per tick to get what the player
## wants, and `frame()` once per drawn frame to move the camera and refresh the HUD.
##
## Touch wins while a thumb is on the screen and for a moment after; otherwise keyboard and
## mouse drive (desktop keeps working).

## Seconds after the last touch before keyboard and mouse take over again.
const TOUCH_GRACE := 2.0

var sim: MatchSim
var toy_id: int = 0
var settings: ControlSettings
var view_rules: ViewRules
var camera: GameCamera
var hud: Hud
var touch: TouchControls
var layer: CanvasLayer
var stub: CombatStub
var source: SimHudSource

var _prev_zoom: bool = false
var _weapon_key: StringName = &"-"
var _last_intent := InputIntent.new()


## `world` is the node the toys are drawn under; the camera goes there.
func setup(match_sim: MatchSim, player_toy: int, world: Node, control_settings: ControlSettings = null,
		combat: CombatStub = null) -> void:
	sim = match_sim
	toy_id = player_toy
	settings = control_settings if control_settings != null else ControlSettings.load_or_default()
	view_rules = ViewRules.from_ruleset(sim.rules)
	stub = combat if combat != null else CombatStub.new()
	camera = GameCamera.new()
	camera.name = "GameCamera"
	camera.setup(view_rules, settings)
	world.add_child(camera)
	camera.make_current()
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
	_sync_weapon()


## What the player wants this tick.
func intent() -> InputIntent:
	var i := InputIntent.new()
	if touch.is_active() and touch.since_touch < TOUCH_GRACE:
		touch.fill(i)
	else:
		var me := sim.toy(toy_id)
		var toy_screen := Vector2.ZERO
		if me != null:
			toy_screen = camera.get_canvas_transform() * me.position
		DesktopInput.fill(i, toy_screen, camera.get_viewport().get_mouse_position())
	var zoom := i.is_down(InputIntent.Act.ZOOM)
	if zoom and not _prev_zoom:
		camera.rig.zoom_tap()
	_prev_zoom = zoom
	camera.rig.set_aim(i.aim)
	_last_intent = i
	return i


## Re-reads the settings into the controls and camera (after the settings screen).
func apply_settings() -> void:
	touch.apply_settings()
	settings.apply_audio()


## One drawn frame. `alpha` is how far the clock is between ticks (SimClock.alpha()).
func frame(dt: float, alpha: float) -> void:
	_sync_weapon()
	var me := sim.toy(toy_id)
	if me != null:
		camera.follow(me.prev_position.lerp(me.position, alpha), dt)
	hud.view_rect = camera.view_rect()
	touch.zoom_label = "%dX" % camera.rig.level
	touch.can_pick_up = hud.state.can_pick_up


func _sync_weapon() -> void:
	if stub.weapon_key == _weapon_key:
		return
	_weapon_key = stub.weapon_key
	var w := WeaponView.for_weapon(_weapon_key)
	camera.rig.set_weapon(w.key, w.zoom_levels, w.look_ahead)

