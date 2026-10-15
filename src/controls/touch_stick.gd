class_name TouchStick
extends RefCounted
## One on-screen stick, as logic only: which touch owns it, where its knob sits, what it reads.
## `TouchControls` draws it and feeds it touches. Tests drive it directly (US-23.2, US-05.1/.2).
##
## Screen space is the UI canvas: x right, y down, in points (one point is one unit of the
## 360-high UI canvas). `output()` is stick space: x right, y up, each axis -1 to 1.

## Where the stick rests when no thumb holds it.
var home: Vector2 = Vector2.ZERO
## Where the stick is centred now: `home`, or where the thumb landed when floating (US-23.3).
var center: Vector2 = Vector2.ZERO
## T-85: knob travel, points (already multiplied by the stick size setting).
var radius: float = 40.0
## T-85: a touch that starts within this many points of `center` is taken by the stick.
var capture: float = 90.0
## T-85: share of the way back to centre the knob moves each 1/60 s once let go.
var knob_return: float = 0.2
## US-23.3: the stick centres where the thumb lands.
var floating: bool = false
## Codes as the classic's: 0 none, 1 flip x, 2 flip y, 3 both (US-42.1).
var invert: int = 0

## Touch index that owns the stick, -1 when free.
var touch: int = -1
## Knob offset from `center`, points, y down. Never longer than `radius`.
var knob: Vector2 = Vector2.ZERO
## Where the owning thumb is, unclamped, for the fire rule.
var thumb: Vector2 = Vector2.ZERO


func _init(at: Vector2 = Vector2.ZERO, stick_radius: float = 40.0, capture_radius: float = 90.0) -> void:
	home = at
	center = at
	radius = stick_radius
	capture = capture_radius


func held() -> bool:
	return touch >= 0


## Would a touch starting at `pos` go to this stick? Floating sticks take any touch the caller
## routes to them (their side of the screen); fixed ones only within `capture`.
func reaches(pos: Vector2) -> bool:
	if touch >= 0:
		return false
	return floating or pos.distance_to(home) <= capture


## Takes touch `index` if it reaches. Returns true when the stick took it.
func press(index: int, pos: Vector2) -> bool:
	if not reaches(pos):
		return false
	touch = index
	center = pos if floating else home
	_follow(pos)
	return true


## Follows the owning touch wherever it goes, even far outside the stick (US-23.2).
func drag(index: int, pos: Vector2) -> void:
	if index == touch:
		_follow(pos)


func release(index: int) -> void:
	if index != touch:
		return
	touch = -1


## Frees the stick at once, knob centred (focus lost, pause).
func reset() -> void:
	touch = -1
	knob = Vector2.ZERO
	thumb = center
	center = home


## Visual and output easing once let go: the knob slides home (T-85). Frame-rate free.
func step(dt: float) -> void:
	if touch >= 0:
		return
	knob *= pow(1.0 - knob_return, dt * 60.0)
	if knob.length() < 0.01:
		knob = Vector2.ZERO
		center = home


## Knob offset over radius, stick space (y up), each axis -1 to 1. No dead zone (T-85): any
## offset counts.
func output() -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var v := Vector2(knob.x, -knob.y) / radius
	if invert & 1:
		v.x = -v.x
	if invert & 2:
		v.y = -v.y
	return v.limit_length(1.0)


## Direction from the centre to the thumb at any distance, stick space, length 1; zero when
## free or dead centre (US-05.1).
func direction() -> Vector2:
	if touch < 0:
		return Vector2.ZERO
	var d := thumb - center
	if d.length_squared() < 1e-6:
		return Vector2.ZERO
	var v := Vector2(d.x, -d.y).normalized()
	if invert & 1:
		v.x = -v.x
	if invert & 2:
		v.y = -v.y
	return v


## T-86: the thumb is held past the ring's edge.
func past_ring() -> bool:
	return touch >= 0 and thumb.distance_to(center) > radius


func _follow(pos: Vector2) -> void:
	thumb = pos
	knob = (pos - center).limit_length(radius)
