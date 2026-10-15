class_name TeamLook
extends RefCounted
## How a team shows on a toy (US-26.1, US-26.2): the batteries and wires in the team colour
## with a pattern per team (plain, stripes, dots, chevrons), and a thin outline in the team
## colour around the whole toy. Free-for-all toys keep the copper-top battery (art lab default,
## accepted 2026-10-15).
##
## Teams are the combat sim's: 0 is no team, 1 and up are teams. Colours are the art lab's
## (bni-hub questions, 2026-10-15). The controls and HUD task carries a `TeamPalette` with the
## same colours for name tags; when both are on main this reads its colours from there.

const COLORS: Array[Color] = [Color("1f63d6"), Color("ff8c1a"), Color("ff8fcb"), Color("f2d02b")]
const BAKED: PackedStringArray = ["blue", "orange", "pink", "yellow"]
const FFA_OUTLINE := Color("1e1a22")
const OUTLINE_DARKEN := 0.12

const OUTLINE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
// A thin outline around everything drawn inside the CanvasGroup (US-26.1, US-26.4).
uniform vec4 outline_color : source_color = vec4(0.12, 0.39, 0.84, 1.0);
uniform float width = 2.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	float around = 0.0;
	for (int i = 0; i < 8; i++) {
		float t = 6.2831853 * float(i) / 8.0;
		around = max(around, textureLod(screen_texture, SCREEN_UV + vec2(cos(t), sin(t)) * width * SCREEN_PIXEL_SIZE, 0.0).a);
	}
	vec4 line = vec4(outline_color.rgb, outline_color.a * around);
	COLOR = mix(line, c, c.a);
}
"""

static var _shader: Shader


static func outline_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OUTLINE_SHADER
	return _shader


static func index(team: int) -> int:
	return -1 if team <= Fighter.NO_TEAM else (team - 1) % COLORS.size()


static func battery_color(team: int) -> Color:
	var i := index(team)
	return Color.WHITE if i < 0 else COLORS[i]


static func outline_color(team: int) -> Color:
	var i := index(team)
	return FFA_OUTLINE if i < 0 else COLORS[i].darkened(OUTLINE_DARKEN)


## The overlay drawn over the tinted greyscale layer: a pattern piece, "" for plain, or
## "baked" when the toy uses a baked layer instead (free-for-all).
static func pattern_piece(team: int) -> StringName:
	var i := index(team)
	if i < 0:
		return &"baked"
	var kind := ArtLibrary.TEAM_PATTERNS[i % ArtLibrary.TEAM_PATTERNS.size()]
	return &"" if kind == "" else StringName(ArtLibrary.SOLDIER + "jetpack_pattern_" + kind)


static func baked_piece(team: int) -> StringName:
	var i := index(team)
	var name := "neutral" if i < 0 else BAKED[i]
	return StringName(ArtLibrary.SOLDIER + "jetpack_team_" + name)
