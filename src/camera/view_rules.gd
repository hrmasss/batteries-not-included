class_name ViewRules
extends RefCounted
## The controls and camera values from the ruleset (04_tuning T-80 to T-88), in one place for
## the view layer. Built from a checked `Ruleset`; nothing here holds a start value.

## T-80: view scale for zoom levels 1X to 7X; index 0 is 1X. Lower shows more map.
var zoom_scales: PackedFloat32Array = []
## T-81: look-ahead share of (W/4, H/4) at 100%, the player's default (AIM OFFSET 75%).
var look_ahead: float = 0.0
## T-81: weapon factor floor, and the factor with no gun.
var look_ahead_floor: float = 0.0
var look_ahead_bare: float = 0.0
## T-82: look-ahead panning speed, /s.
var panning_speed: float = 0.0
## T-83: zoom speed, /s; 0 snaps.
var zoom_speed: float = 0.0
## T-84: the toy body sits this many points below the middle of the screen.
var anchor_below_middle: float = 0.0
## T-88: world height a 16:9 screen shows at 1X.
var view_height: float = 0.0
## T-85: stick radius at size 1, capture distance, knob return per 1/60 s.
var stick_radius: float = 0.0
var stick_capture: float = 0.0
var knob_return: float = 0.0
## T-87: radar range, speed trigger, ring radius as a share of screen height, on-screen margin.
var radar_range: float = 0.0
var radar_speed: float = 0.0
var radar_ring: float = 0.0
var radar_margin: float = 0.0
## T-63: blast shake strength ((peak × power − d) × power × scale), at least `shake_min`, in u.
## How far a blast shakes comes with the sim's blast event (throwables `blast_shake_reach`).
var shake_peak_reach: float = 0.0
var shake_scale: float = 0.0
var shake_min: float = 0.0


static func from_ruleset(r: Ruleset) -> ViewRules:
	var v := ViewRules.new()
	v.zoom_scales = PackedFloat32Array([r.zoom_scale_1, r.zoom_scale_2, r.zoom_scale_3, r.zoom_scale_4,
		r.zoom_scale_5, r.zoom_scale_6, r.zoom_scale_7])
	v.look_ahead = r.look_ahead
	v.look_ahead_floor = r.look_ahead_floor
	v.look_ahead_bare = r.look_ahead_bare
	v.panning_speed = r.panning_speed
	v.zoom_speed = r.zoom_speed
	v.anchor_below_middle = r.anchor_below_middle
	v.view_height = r.view_height
	v.stick_radius = r.stick_radius
	v.stick_capture = r.stick_capture
	v.knob_return = r.knob_return
	v.radar_range = r.radar_range
	v.radar_speed = r.radar_speed
	v.radar_ring = r.radar_ring
	v.radar_margin = r.radar_margin
	v.shake_peak_reach = r.shake_peak_reach
	v.shake_scale = r.shake_scale
	v.shake_min = r.shake_min
	return v


## Highest zoom level on the ladder (7 for 1X to 7X).
func top_level() -> int:
	return zoom_scales.size()


func scale_for(level: int) -> float:
	return zoom_scales[clampi(level, 1, zoom_scales.size()) - 1]
