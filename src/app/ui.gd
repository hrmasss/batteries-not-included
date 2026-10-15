class_name Ui
extends RefCounted
## Shared look and small builders for the menus: a night-bedroom navy, battery copper for the
## main action, chunky buttons big enough for a thumb. Placeholder look until the HUD's own art.

const BG := Color("#141a33")
const PANEL := Color("#1f2850")
const PANEL_LIGHT := Color("#2b3666")
const ACCENT := Color("#e08a2c")
const ACCENT_DARK := Color("#a85f17")
const TEXT := Color("#f4f1ea")
const TEXT_DIM := Color("#a9b0cf")
const GOOD := Color("#7fd18b")
## A glyph for each team shape (TeamPalette.SHAPES), so a team never rests on colour.
const SHAPE_GLYPHS := {TeamPalette.Shape.CIRCLE: "●", TeamPalette.Shape.TRIANGLE: "▲", TeamPalette.Shape.SQUARE: "■", TeamPalette.Shape.DIAMOND: "◆"}
const FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"

const BUTTON_HEIGHT := 34.0
const FONT_SMALL := 11
const FONT := 14
const FONT_BIG := 20
const FONT_TITLE := 30


## Match teams count from 1; the palette from 0.
static func team_color(team: int) -> Color:
	return TeamPalette.color(team - 1) if team > 0 else TEXT


static func team_glyph(team: int) -> String:
	return SHAPE_GLYPHS.get(TeamPalette.shape(team - 1), "") if team > 0 else ""


## "▲ Orange"
static func team_name(team: int) -> String:
	return "%s %s" % [team_glyph(team), TeamPalette.team_name(team - 1)] if team > 0 else ""


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT
	if ResourceLoader.exists(FONT_PATH):
		t.default_font = load(FONT_PATH)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_stylebox("normal", "Button", _box(PANEL_LIGHT))
	t.set_stylebox("hover", "Button", _box(PANEL_LIGHT.lightened(0.12)))
	t.set_stylebox("pressed", "Button", _box(PANEL_LIGHT.darkened(0.2)))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT))
	t.set_stylebox("disabled", "Button", _box(PANEL))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL))
	t.set_color("font_color", "CheckButton", TEXT)
	return t


static func _box(c: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(8)
	b.set_content_margin_all(6)
	if border.a > 0.0:
		b.set_border_width_all(2)
		b.border_color = border
	return b


## A full-screen backdrop with a centred column, for a menu screen.
static func screen(parent: Control) -> VBoxContainer:
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.theme = theme()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	parent.add_child(margin)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	return col


static func label(text: String, size: int = FONT, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable, main: bool = false, width: float = 200.0) -> Button:
	var b := Button.new()
	b.text = text
	b.name = text.validate_node_name().to_pascal_case()
	b.custom_minimum_size = Vector2(width, BUTTON_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_ALL
	if main:
		b.add_theme_stylebox_override("normal", _box(ACCENT))
		b.add_theme_stylebox_override("hover", _box(ACCENT.lightened(0.1)))
		b.add_theme_stylebox_override("pressed", _box(ACCENT_DARK))
		b.add_theme_font_size_override("font_size", FONT_BIG)
	b.pressed.connect(on_press)
	return b


static func row(children: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	for c: Control in children:
		h.add_child(c)
	return h


## mm:ss
static func clock(seconds: float) -> String:
	var s := ceili(maxf(seconds, 0.0))
	return "%d:%02d" % [s / 60, s % 60]
