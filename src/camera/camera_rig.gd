class_name CameraRig
extends RefCounted
## What the camera shows, as logic only (US-24, US-10, T-80 to T-84, T-88): the anchor, the aim
## look-ahead, easing to the zoom level and the shake. `GameCamera` applies it to a Camera2D;
## tests drive it directly.
##
## The sim owns the zoom level and per-weapon memory (`Fighter.zoom_level`); the rig only eases
## the view to it and reads the held weapon's look-ahead factor (`WeaponDef.look_ahead`).
##
## World space is Godot's: y down, 1 unit = 1 u. Aim and stick vectors are y up.

## The 16:9 shape every screen's view area is normalised to (T-88).
const BASE_ASPECT := 16.0 / 9.0
## Shake fades by half every this many seconds. Ours: the classic's effects manager was not read.
const SHAKE_HALF_LIFE := 0.08

var rules: ViewRules
var settings: ControlSettings

## Look-ahead now and its target, in shares of (W/4, H/4) of the visible world, y down.
var look: Vector2 = Vector2.ZERO
var look_target: Vector2 = Vector2.ZERO
## Last aim direction, y up. The view keeps looking that way after the thumb lifts.
var aim_dir: Vector2 = Vector2.ZERO
## Zoom level on the ladder (1 is 1X), from the sim, and the scale easing toward it.
var level: int = 1
var scale: float = 1.0
## The held weapon's look-ahead factor (T-81), floored.
var weapon_factor: float = 0.0
## Shake strength now, u, before the player's setting.
var shake: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO

var _rng := RandomNumberGenerator.new()


func _init(view_rules: ViewRules, control_settings: ControlSettings) -> void:
	rules = view_rules
	settings = control_settings
	scale = rules.scale_for(1)
	weapon_factor = maxf(rules.look_ahead_bare, rules.look_ahead_floor)
	_rng.seed = 1


## World size a screen of `aspect` (width / height) shows at the current scale. Every shape sees
## the same area (T-88, US-24.3): the 16:9 view's area, divided by scale squared.
func visible_world(aspect: float) -> Vector2:
	var area := rules.view_height * rules.view_height * BASE_ASPECT
	var h := sqrt(area / aspect) / scale
	return Vector2(aspect * h, h)


## Where the camera centre goes for a toy whose body origin is at `body`, on a screen of
## `aspect` whose UI canvas is `canvas_height` points tall.
func center_for(body: Vector2, aspect: float, canvas_height: float) -> Vector2:
	var view := visible_world(aspect)
	# T-84: the body sits `anchor_below_middle` points below the middle, so the centre is above it.
	var anchor := Vector2(0.0, -rules.anchor_below_middle * view.y / canvas_height)
	var ahead := Vector2(view.x * 0.25 * look.x, view.y * 0.25 * look.y)
	return body + anchor + ahead + shake_offset * settings.shake


## The toy body's place on screen, in shares of the screen from its centre (y down), with no
## look-ahead or shake. US-24.1 checks this against T-84.
func anchor_share(aspect: float, canvas_height: float) -> Vector2:
	return Vector2(0.0, rules.anchor_below_middle / canvas_height)


## What the player's fighter holds now (US-10, T-81): its zoom level, from the sim, and the held
## weapon's look-ahead factor, or a negative number for bare hands.
func set_held(zoom_level: int, factor: float) -> void:
	level = clampi(zoom_level, 1, rules.top_level())
	weapon_factor = maxf(factor if factor >= 0.0 else rules.look_ahead_bare, rules.look_ahead_floor)


## Aim this tick, y up; zero when the thumb is off the aim stick.
func set_aim(aim: Vector2) -> void:
	if aim.length_squared() > 1e-6:
		aim_dir = aim.normalized()


## A blast at distance `d` with `power` (T-63): the classic's shake rule. `reach` is how far
## this blast shakes screens, from the sim's blast event.
func blast(d: float, power: float, reach: float) -> void:
	if d > reach:
		return
	var strength := maxf((rules.shake_peak_reach * power - d) * power * rules.shake_scale, rules.shake_min)
	shake = maxf(shake, strength)


## One view frame. Frame-rate free.
func step(dt: float) -> void:
	var k := weapon_factor if settings.look_ahead_mode == ControlSettings.LookAheadMode.ADAPTIVE else 1.0
	look_target = Vector2(aim_dir.x, -aim_dir.y) * settings.effective_look_ahead(rules) * k
	look += (look_target - look) * minf(1.0, dt * settings.effective_panning(rules))
	var target := rules.scale_for(level)
	var speed := settings.effective_zoom_speed(rules)
	if speed <= 0.0:
		scale = target
	else:
		scale += (target - scale) * minf(1.0, dt * speed)
		if absf(target - scale) < 1e-4:
			scale = target
	if shake > 0.0:
		shake *= pow(0.5, dt / SHAKE_HALF_LIFE)
		if shake < 0.05:
			shake = 0.0
		var a := _rng.randf() * TAU
		shake_offset = Vector2(cos(a), sin(a)) * shake
	else:
		shake_offset = Vector2.ZERO
