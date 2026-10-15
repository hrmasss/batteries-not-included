class_name HudStyle
extends RefCounted
## The HUD's look, in one place (US-25.6). Styled to the art taste (`docs/art/` in the
## workspace): chunky molded-plastic pieces with a dark ink line, bright toy colours, a cream
## plastic face, and numbers in a round heavy face. Not a generic thin overlay.

const FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"

## Ink: outlines and text shadow.
const INK := Color("2b2233")
## Plastic: the cream face of panels and buttons.
const PLASTIC := Color("fff4e0")
const PLASTIC_SHADE := Color("e6d3b3")
## Panel fill behind meters, ink at low alpha so the map shows through.
const PANEL := Color(0.169, 0.133, 0.2, 0.62)
const HEALTH := Color("ff4f5e")
const HEALTH_LOW := Color("ffb02e")
const BATTERY_CHARGE := Color("8be04e")
const BATTERY_LOW := Color("ff8c1a")
## AA battery: copper body, black band.
const BATTERY_COPPER := Color("c8813a")
const BATTERY_BAND := Color("2a2a2e")
const AMMO := Color("ffd23f")
const HIT := Color("ff3b30")
const TEXT := Color("fff8ec")

static var _font: Font


static func font() -> Font:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH)
		else:
			_font = ThemeDB.fallback_font
	return _font


## Text with a dark ink edge, so it reads on any map. `pos` is the left of the baseline.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color = TEXT,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f := font()
	ci.draw_string_outline(f, pos, s, align, width, size, maxi(2, size / 5), Color(INK, color.a))
	ci.draw_string(f, pos, s, align, width, size, color)


static func text_width(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## A rounded plastic slab: ink rim, fill, and a lighter top lip.
static func slab(ci: CanvasItem, rect: Rect2, fill: Color, radius: float = 8.0, rim: float = 2.5) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(radius))
	box.border_color = Color(INK, fill.a)
	box.set_border_width_all(int(rim))
	box.anti_aliasing = true
	ci.draw_style_box(box, rect)
	var lip := StyleBoxFlat.new()
	lip.bg_color = Color(1, 1, 1, 0.16 * fill.a)
	lip.set_corner_radius_all(int(maxf(radius - rim, 1.0)))
	lip.anti_aliasing = true
	var inner := rect.grow(-rim)
	inner.size.y = maxf(inner.size.y * 0.4, 1.0)
	ci.draw_style_box(lip, inner)


## A round plastic button face: shadow, ink rim, fill, highlight.
static func disc(ci: CanvasItem, c: Vector2, r: float, fill: Color, alpha: float = 1.0) -> void:
	ci.draw_circle(c + Vector2(0, r * 0.1), r, Color(INK, 0.45 * alpha))
	ci.draw_circle(c, r, Color(INK, alpha))
	ci.draw_circle(c, r - maxf(2.0, r * 0.09), Color(fill, fill.a * alpha))
	ci.draw_circle(c + Vector2(0, -r * 0.28), r * 0.55, Color(1, 1, 1, 0.18 * alpha))
