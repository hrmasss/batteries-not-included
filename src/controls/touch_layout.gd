class_name TouchLayout
extends RefCounted
## Where the sticks and buttons sit on a screen of a given size (US-23.1, US-23.4).
##
## Positions follow the classic's phone defaults (controls-hud-camera.md, "Default control
## layout, phone"), written there from the bottom left; here they are converted to the UI
## canvas (y down). The full drag-and-resize editor is R2 (US-23.7).

enum Id { MOVE, AIM, GRENADE, MELEE, RELOAD, SWITCH, PICK_UP, ZOOM, GRENADE_SWITCH, FIRE }

## Side margin from the screen edge for the sticks, points. The classic's `boundarySize` was
## not recovered; this is ours.
const EDGE := 20.0
## Button radius at size 1, points. Ours: the classic's sprite size was not read.
const BUTTON_RADIUS := 30.0
## The classic's default button size.
const BUTTON_SCALE := 0.8

## Where each control sits, `Id` to centre (canvas points, y down).
var centers: Dictionary = {}
## Each button's radius; the sticks' radius comes from the ruleset and the size setting.
var radii: Dictionary = {}
var size: Vector2 = Vector2.ZERO


## Lays out a `screen` sized UI canvas.
static func build(screen: Vector2, settings: ControlSettings) -> TouchLayout:
	var l := TouchLayout.new()
	l.size = screen
	var w := screen.x
	var h := screen.y
	var b := BUTTON_RADIUS * BUTTON_SCALE * settings.button_size
	# Classic positions: (x, y from the bottom).
	l._put(Id.MOVE, Vector2(80.0 + EDGE, 80.0), 0.0)
	l._put(Id.AIM, Vector2(w - 80.0 - EDGE, 80.0), 0.0)
	l._put(Id.GRENADE, Vector2(190.0 + EDGE, 35.0), b)
	l._put(Id.MELEE, Vector2(w - 190.0 - EDGE, 35.0), b)
	l._put(Id.RELOAD, Vector2(w - 34.0, h - 34.0), b)
	l._put(Id.ZOOM, Vector2(34.0, h - 34.0), b)
	l._put(Id.SWITCH, Vector2(w - 34.0, h - 85.0), b)
	l._put(Id.GRENADE_SWITCH, Vector2(34.0, h - 85.0), b)
	l._put(Id.PICK_UP, Vector2(w * 0.5, 35.0), b)
	l._put(Id.FIRE, Vector2(w - 85.0, h - 140.0), b * 1.25)
	if settings.left_handed:
		l._mirror()
	return l


func center(id: Id) -> Vector2:
	return centers[id]


func radius(id: Id) -> float:
	return radii.get(id, 0.0)


## The button under `pos`, or -1. Sticks are not buttons. Hidden buttons (the fire button when
## off, pick up with nothing in reach) take no touches.
func button_at(pos: Vector2, fire_on: bool, pick_up_on: bool = true) -> int:
	var best := -1
	var best_d := INF
	for id: int in radii:
		if (id == Id.FIRE and not fire_on) or (id == Id.PICK_UP and not pick_up_on):
			continue
		var d := pos.distance_to(centers[id])
		# A little slack around each button: thumbs are wide.
		if d <= radii[id] * 1.25 and d < best_d:
			best = id
			best_d = d
	return best


## True when `pos` is on the move stick's half of the screen.
func on_move_side(pos: Vector2) -> bool:
	return (pos.x < size.x * 0.5) == (centers[Id.MOVE].x < size.x * 0.5)


func _put(id: Id, from_bottom_left: Vector2, r: float) -> void:
	centers[id] = Vector2(from_bottom_left.x, size.y - from_bottom_left.y)
	if r > 0.0:
		radii[id] = r


func _mirror() -> void:
	for id: int in centers:
		var c: Vector2 = centers[id]
		centers[id] = Vector2(size.x - c.x, c.y)
