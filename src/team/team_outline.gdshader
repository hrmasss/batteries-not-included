// A thin team outline around everything drawn inside a CanvasGroup (01_world "Teams", US-26.1).
// Put the toy's parts under a `TeamOutline` (a CanvasGroup) and this draws the team colour
// just outside their combined silhouette, so cosmetics never cover it (US-26.4).
shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.18, 0.49, 0.88, 1.0);
// Outline width in screen pixels.
uniform float width : hint_range(0.0, 8.0) = 2.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	float around = 0.0;
	for (int i = 0; i < 12; i++) {
		float t = 6.2831853 * float(i) / 12.0;
		vec2 off = vec2(cos(t), sin(t)) * width * SCREEN_PIXEL_SIZE;
		around = max(around, textureLod(screen_texture, SCREEN_UV + off, 0.0).a);
	}
	vec4 line = vec4(outline_color.rgb, outline_color.a * around);
	COLOR = mix(line, c, c.a);
}
