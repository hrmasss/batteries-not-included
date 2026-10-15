class_name HudIcons
extends RefCounted
## Small vector icons for buttons and the HUD, drawn in code so they stay crisp at any size.
## `s` is the icon's half size; `c` its centre.

enum Kind { GRENADE, MELEE, RELOAD, SWITCH, PICK_UP, ZOOM, GRENADE_SWITCH, FIRE, HEART, SKULL, GUN }


static func draw(ci: CanvasItem, kind: Kind, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.18)
	match kind:
		Kind.GRENADE:
			_grenade(ci, c, s, col, w)
		Kind.MELEE:
			# A toy knife: blade up and right, chunky handle.
			var a := c + Vector2(-0.55, 0.55) * s
			var b := c + Vector2(0.65, -0.65) * s
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-0.15, 0.05) * s, b, c + Vector2(0.15, -0.05) * s + Vector2(0.12, 0.12) * s,
				c + Vector2(0.05, 0.25) * s]), col)
			ci.draw_line(a, c + Vector2(-0.1, 0.1) * s, col, w * 1.8, true)
			ci.draw_line(c + Vector2(-0.3, -0.05) * s, c + Vector2(0.05, 0.3) * s, col, w, true)
		Kind.RELOAD:
			ci.draw_arc(c, s * 0.6, -PI * 0.15, PI * 1.45, 20, col, w, true)
			var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * s * 0.6
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.3, -0.25) * s,
				tip + Vector2(0.3, -0.05) * s, tip + Vector2(0.0, 0.35) * s]), col)
		Kind.SWITCH:
			_arrow(ci, c + Vector2(0, -0.28) * s, Vector2.RIGHT, s * 0.75, col, w)
			_arrow(ci, c + Vector2(0, 0.28) * s, Vector2.LEFT, s * 0.75, col, w)
		Kind.PICK_UP:
			# A hand-sized box with an arrow into it.
			ci.draw_rect(Rect2(c + Vector2(-0.6, 0.05) * s, Vector2(1.2, 0.55) * s), col, false, w)
			_arrow(ci, c + Vector2(0, -0.35) * s, Vector2.DOWN, s * 0.7, col, w)
		Kind.ZOOM:
			ci.draw_arc(c + Vector2(-0.12, -0.12) * s, s * 0.42, 0, TAU, 20, col, w, true)
			ci.draw_line(c + Vector2(0.18, 0.18) * s, c + Vector2(0.62, 0.62) * s, col, w * 1.6, true)
		Kind.GRENADE_SWITCH:
			_grenade(ci, c + Vector2(-0.12, 0.05) * s, s * 0.75, col, w)
			ci.draw_arc(c, s * 0.82, -PI * 0.35, PI * 0.35, 10, col, w * 0.8, true)
			var tip := c + Vector2(cos(PI * 0.35), sin(PI * 0.35)) * s * 0.82
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.22, 0.0) * s,
				tip + Vector2(0.2, -0.2) * s, tip + Vector2(0.18, 0.22) * s]), col)
		Kind.FIRE:
			ci.draw_arc(c, s * 0.55, 0, TAU, 20, col, w, true)
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * s * 0.3, c + d * s * 0.85, col, w, true)
		Kind.HEART:
			var pts := PackedVector2Array()
			for i in 32:
				var t := TAU * i / 32.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(c + Vector2(x, y) * s / 17.0)
			ci.draw_colored_polygon(pts, col)
		Kind.SKULL:
			# A popped toy: a burst star, never gore.
			var pts := PackedVector2Array()
			for i in 16:
				var r := s * (0.85 if i % 2 == 0 else 0.45)
				var t := TAU * i / 16.0
				pts.append(c + Vector2(cos(t), sin(t)) * r)
			ci.draw_colored_polygon(pts, col)
		Kind.GUN:
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.3) * s, Vector2(1.5, 0.35) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-0.6, 0.0) * s, Vector2(0.35, 0.6) * s), col)


static func _grenade(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	ci.draw_circle(c + Vector2(0, 0.15) * s, s * 0.55, col)
	ci.draw_rect(Rect2(c + Vector2(-0.22, -0.62) * s, Vector2(0.44, 0.3) * s), col)
	ci.draw_arc(c + Vector2(0.38, -0.55) * s, s * 0.2, 0, TAU, 10, col, w * 0.7, true)


static func _arrow(ci: CanvasItem, c: Vector2, dir: Vector2, len: float, col: Color, w: float) -> void:
	var a := c - dir * len * 0.5
	var b := c + dir * len * 0.5
	ci.draw_line(a, b - dir * w, col, w, true)
	var side := Vector2(-dir.y, dir.x)
	ci.draw_colored_polygon(PackedVector2Array([b + dir * w * 0.5, b - dir * len * 0.38 + side * len * 0.3,
		b - dir * len * 0.38 - side * len * 0.3]), col)
