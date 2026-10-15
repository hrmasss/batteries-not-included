class_name TeamPalette
extends RefCounted
## Team colours and team shapes (01_world "Teams and telling them apart", US-26, NF-13).
##
## A team never rests on colour alone: each has a shape for name tags and HUD marks, and the
## colours differ in lightness as well as hue. Colours from the art task's default
## (bni-hub questions, 2026-10-15): blue, orange, pink, yellow; none green, so they never melt
## into the soldier. Free-for-all toys get copper-black batteries.
##
## The colour-vision setting (US-42.4) swaps to a palette that stays apart for the common
## deficiencies; the shapes stay the same.

enum Shape { CIRCLE, TRIANGLE, SQUARE, DIAMOND }

const COLORS: Array[Color] = [Color("2f7de1"), Color("ff8c1a"), Color("e0509e"), Color("f2d02b")]
## Blue, orange, magenta-pink, pale yellow: apart in lightness and on the blue-yellow axis.
const COLORS_CVD: Array[Color] = [Color("1f5fd6"), Color("ff9d00"), Color("b0007a"), Color("f5e663")]
const NAMES: PackedStringArray = ["Blue", "Orange", "Pink", "Yellow"]
const SHAPES: Array[Shape] = [Shape.CIRCLE, Shape.TRIANGLE, Shape.SQUARE, Shape.DIAMOND]
const FFA_BATTERY := Color("3a2a22")
const FFA_WIRE := Color("c8813a")
## Outline is the team colour darkened a little, so it reads on light and dark maps alike.
const OUTLINE_DARKEN := 0.15

static var colour_vision: bool = false


static func color(team: int) -> Color:
	if team < 0:
		return FFA_WIRE
	var set := COLORS_CVD if colour_vision else COLORS
	return set[team % set.size()]


static func battery_color(team: int) -> Color:
	return FFA_BATTERY if team < 0 else color(team)


static func wire_color(team: int) -> Color:
	return FFA_WIRE if team < 0 else color(team).lightened(0.2)


static func outline_color(team: int) -> Color:
	return Color(0.12, 0.1, 0.14) if team < 0 else color(team).darkened(OUTLINE_DARKEN)


static func shape(team: int) -> Shape:
	return SHAPES[team % SHAPES.size()] if team >= 0 else Shape.CIRCLE


static func team_name(team: int) -> String:
	return NAMES[team % NAMES.size()] if team >= 0 else ""


## Draws a team's shape at `c`, half size `s`, with an ink rim.
static func draw_shape(ci: CanvasItem, team: int, c: Vector2, s: float, alpha: float = 1.0) -> void:
	var col := Color(color(team), alpha)
	var ink := Color(HudStyle.INK, alpha)
	var pts := shape_points(shape(team), c, s)
	if pts.is_empty():
		ci.draw_circle(c, s + 1.5, ink)
		ci.draw_circle(c, s, col)
		return
	var rim := shape_points(shape(team), c, s + 2.0)
	ci.draw_colored_polygon(rim, ink)
	ci.draw_colored_polygon(pts, col)


## Polygon for a shape; empty for a circle.
static func shape_points(sh: Shape, c: Vector2, s: float) -> PackedVector2Array:
	match sh:
		Shape.TRIANGLE:
			return PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s * 1.05, s * 0.8), c + Vector2(-s * 1.05, s * 0.8)])
		Shape.SQUARE:
			return PackedVector2Array([c + Vector2(-s, -s) * 0.9, c + Vector2(s, -s) * 0.9, c + Vector2(s, s) * 0.9, c + Vector2(-s, s) * 0.9])
		Shape.DIAMOND:
			return PackedVector2Array([c + Vector2(0, -s * 1.2), c + Vector2(s, 0), c + Vector2(0, s * 1.2), c + Vector2(-s, 0)])
	return PackedVector2Array()
