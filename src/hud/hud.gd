class_name Hud
extends Control
## The in-match HUD (US-25): health and battery together, ammo and reserve, grenades by type, the
## clock and scores, the kill feed, the respawn panel, radar edge arrows and hit direction.
## Draws what its `HudSource` gives it; decides nothing.
##
## Lay it over the whole screen in a CanvasLayer. Everything sits clear of the sticks' thumb
## areas (US-25.5): the meters and clock along the top centre, the feed under the right meter.

const HIT_LIFE := 1.0

var source: HudSource
var state := HudState.new()
var radar: Radar
## The visible world rect this frame, from the camera, for the radar.
var view_rect: Rect2 = Rect2()

## Hit markers: direction (y down) and age.
var _hits: Array[Dictionary] = []
var _t: float = 0.0


func setup(hud_source: HudSource, view_rules: ViewRules) -> void:
	source = hud_source
	radar = Radar.new(view_rules)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	if source == null:
		return
	_t += dt
	source.read(state, dt)
	if view_rect.size != Vector2.ZERO:
		radar.step(dt, state.my_position, view_rect, state.my_team, state.contacts)
	for from in state.hits_from:
		var d := from - state.my_position
		if d.length_squared() > 1e-6:
			_hits.append({"dir": d.normalized(), "age": 0.0})
	for h in _hits:
		h.age += dt
	_hits = _hits.filter(func(h: Dictionary) -> bool: return h.age < HIT_LIFE)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	_draw_radar()
	_draw_hits()
	_draw_vitals(Rect2(w * 0.5 - 222.0, 6.0, 168.0, 40.0))
	_draw_clock(Vector2(w * 0.5, 6.0))
	_draw_ammo(Rect2(w * 0.5 + 54.0, 6.0, 168.0, 40.0))
	_draw_feed(Vector2(w * 0.5 + 222.0, 62.0))
	if state.popped:
		_draw_respawn()


# --- health and battery (US-25.1, US-25.2) ---

func _draw_vitals(r: Rect2) -> void:
	HudStyle.slab(self, r, HudStyle.PANEL, 10.0, 2.0)
	# Health: heart and bar.
	var hp := clampf(state.health / maxf(state.health_max, 1.0), 0.0, 1.0)
	var heart_c := r.position + Vector2(15.0, 13.0)
	var beat := 1.0 + (0.12 * absf(sin(_t * 6.0)) if hp < 0.3 else 0.0)
	HudIcons.draw(self, HudIcons.Kind.HEART, heart_c + Vector2(0, 1), 9.0 * beat, HudStyle.INK)
	HudIcons.draw(self, HudIcons.Kind.HEART, heart_c, 8.0 * beat, HudStyle.HEALTH)
	var bar := Rect2(r.position + Vector2(28.0, 7.0), Vector2(r.size.x - 66.0, 12.0))
	_bar(bar, hp, HudStyle.HEALTH if hp >= 0.3 else HudStyle.HEALTH_LOW)
	HudStyle.text(self, Vector2(bar.end.x + 4.0, bar.end.y + 1.0), str(ceili(state.health)), 15, HudStyle.TEXT)
	# Battery: an AA battery lying on its side.
	var batt := Rect2(r.position + Vector2(8.0, 23.0), Vector2(r.size.x - 46.0, 12.0))
	var share := 1.0 if state.batteries_included else clampf(state.battery / maxf(state.battery_max, 0.001), 0.0, 1.0)
	_battery(batt, share)
	if state.batteries_included:
		_infinity(Vector2(batt.end.x + 18.0, batt.get_center().y), 7.0)
	else:
		HudStyle.text(self, Vector2(batt.end.x + 8.0, batt.end.y + 1.0), str(roundi(share * 100.0)), 13, HudStyle.TEXT)


func _bar(r: Rect2, share: float, col: Color) -> void:
	HudStyle.slab(self, r, Color(HudStyle.INK, 0.9), 5.0, 1.5)
	if share > 0.0:
		var f := Rect2(r.position + Vector2(2, 2), Vector2((r.size.x - 4.0) * share, r.size.y - 4.0))
		HudStyle.slab(self, f, col, 4.0, 0.0)


func _battery(r: Rect2, share: float) -> void:
	# Copper body with a dark band at the minus end and a nub on the plus end, the charge as a
	# lit window along the body.
	var nub := Rect2(Vector2(r.end.x, r.get_center().y - 3.0), Vector2(4.0, 6.0))
	draw_rect(nub.grow(1.5), HudStyle.INK)
	draw_rect(nub, HudStyle.PLASTIC_SHADE)
	HudStyle.slab(self, r, HudStyle.BATTERY_COPPER, 5.0, 1.5)
	draw_rect(Rect2(r.position + Vector2(1.5, 1.5), Vector2(10.0, r.size.y - 3.0)), HudStyle.BATTERY_BAND)
	var win := Rect2(r.position + Vector2(14.0, 3.0), Vector2(r.size.x - 18.0, r.size.y - 6.0))
	draw_rect(win, Color(HudStyle.INK, 0.85))
	var col := HudStyle.BATTERY_CHARGE if share > 0.25 else HudStyle.BATTERY_LOW
	if share > 0.0:
		draw_rect(Rect2(win.position, Vector2(win.size.x * share, win.size.y)), col)
	# Cell ticks so the level reads at a glance.
	for i in range(1, 4):
		var x := win.position.x + win.size.x * i / 4.0
		draw_line(Vector2(x, win.position.y), Vector2(x, win.end.y), Color(HudStyle.INK, 0.6), 1.0)


func _infinity(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var t := TAU * i / 40.0
		var d := 1.0 + sin(t) * sin(t)
		pts.append(c + Vector2(cos(t), sin(t) * cos(t)) * s * 1.4 / d)
	draw_polyline(pts, HudStyle.INK, 5.0, true)
	draw_polyline(pts, HudStyle.BATTERY_CHARGE, 2.5, true)


# --- clock and scores ---

func _draw_clock(top: Vector2) -> void:
	var r := Rect2(top + Vector2(-46.0, 0.0), Vector2(92.0, 28.0))
	HudStyle.slab(self, r, HudStyle.PLASTIC, 9.0, 2.5)
	var txt := "--:--"
	if state.clock >= 0.0:
		var s := ceili(state.clock)
		txt = "%d:%02d" % [s / 60, s % 60]
	var low := state.clock >= 0.0 and state.clock <= 30.0
	HudStyle.text(self, Vector2(r.position.x, r.end.y - 6.0), txt, 20, HudStyle.HIT if low else HudStyle.INK.lightened(0.05), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# Scores under the clock: team chips, or my kills and the leader's.
	var chips := state.scores
	if chips.is_empty():
		return
	var cw := 34.0
	var x := top.x - cw * chips.size() * 0.5
	for sc in chips:
		var chip := Rect2(Vector2(x + 2.0, r.end.y + 3.0), Vector2(cw - 4.0, 17.0))
		var col := TeamPalette.color(sc.team) if sc.team >= 0 else (HudStyle.AMMO if sc.mine else HudStyle.PLASTIC_SHADE)
		HudStyle.slab(self, chip, Color(HudStyle.INK, 0.7), 5.0, 1.5)
		draw_rect(Rect2(chip.position + Vector2(2, chip.size.y - 4.0), Vector2(chip.size.x - 4.0, 2.5)), col)
		if sc.team >= 0:
			TeamPalette.draw_shape(self, sc.team, chip.position + Vector2(8.0, 8.0), 3.5)
		HudStyle.text(self, Vector2(chip.position.x + (6.0 if sc.team >= 0 else 0.0), chip.end.y - 4.0), str(sc.kills), 13, HudStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER, chip.size.x)
		x += cw


# --- ammo and grenades ---

func _draw_ammo(r: Rect2) -> void:
	HudStyle.slab(self, r, HudStyle.PANEL, 10.0, 2.0)
	var mag := "∞" if state.ammo_infinite else str(state.magazine)
	var res := "" if state.ammo_infinite else "/ %d" % state.reserve
	var mag_col := HudStyle.AMMO if state.magazine > 0 or state.ammo_infinite else HudStyle.HIT
	HudIcons.draw(self, HudIcons.Kind.GUN, r.position + Vector2(16.0, 14.0), 9.0, HudStyle.PLASTIC)
	HudStyle.text(self, r.position + Vector2(30.0, 21.0), mag, 21, mag_col)
	var mw := HudStyle.text_width(mag, 21)
	HudStyle.text(self, r.position + Vector2(34.0 + mw, 21.0), res, 13, Color(HudStyle.TEXT, 0.8))
	var label := "RELOADING" if state.reloading else state.weapon_name.to_upper()
	HudStyle.text(self, r.position + Vector2(10.0, 36.0), label, 10, Color(HudStyle.TEXT, 0.85))
	# Grenades by type: an icon and count each, the selected one first and brighter.
	var gx := r.end.x - 12.0
	for i in range(state.grenades.size() - 1, -1, -1):
		var g: HudState.Grenade = state.grenades[i]
		var col := HudStyle.PLASTIC if i == 0 else Color(HudStyle.PLASTIC, 0.55)
		var c := Vector2(gx - 14.0, r.position.y + 14.0)
		HudIcons.draw(self, HudIcons.Kind.GRENADE, c, 8.0, _grenade_color(g.kind, i == 0))
		HudStyle.text(self, Vector2(c.x - 10.0, r.position.y + 35.0), "x%d" % g.count, 11, col, HORIZONTAL_ALIGNMENT_CENTER, 20.0)
		gx -= 26.0


func _grenade_color(kind: StringName, selected: bool) -> Color:
	var col := HudStyle.BATTERY_CHARGE
	match kind:
		&"gas":
			col = Color("b4e04e")
		&"proximity":
			col = HudStyle.HIT
		&"emp":
			col = Color("5ec8ff")
		_:
			col = Color("7fae4a")
	return col if selected else Color(col, 0.55)


# --- kill feed ("popped") ---

func _draw_feed(top_right: Vector2) -> void:
	var y := top_right.y
	for l in state.feed:
		var a := clampf((CombatStub.FEED_LIFE - l.age) / 0.6, 0.0, 1.0)
		var size := 12
		var parts: Array = []
		if l.suicide:
			parts = [[l.victim, l.victim_team], [" popped", -9]]
		else:
			parts = [[l.killer, l.killer_team], [" popped ", -9], [l.victim, l.victim_team]]
		var total := 0.0
		for p in parts:
			total += HudStyle.text_width(p[0], size)
		var shapes := 0.0
		for p in parts:
			if int(p[1]) >= 0:
				shapes += 11.0
		var x := top_right.x - total - shapes - 8.0
		var plate := Rect2(Vector2(x - 6.0, y - 13.0), Vector2(total + shapes + 14.0, 17.0))
		HudStyle.slab(self, plate, Color(HudStyle.INK, 0.5 * a), 6.0, 0.0)
		for p in parts:
			var team := int(p[1])
			if team >= 0:
				TeamPalette.draw_shape(self, team, Vector2(x + 4.0, y - 4.5), 3.5, a)
				x += 11.0
			var col := Color(HudStyle.TEXT, a) if team == -9 else Color(_name_color(team), a)
			if team == -9:
				col = Color(HudStyle.AMMO, a)
			HudStyle.text(self, Vector2(x, y), p[0], size, col)
			x += HudStyle.text_width(p[0], size)
		y += 19.0


func _name_color(team: int) -> Color:
	return TeamPalette.color(team).lightened(0.25) if team >= 0 else HudStyle.TEXT


# --- respawn countdown ---

func _draw_respawn() -> void:
	var c := size * 0.5
	var r := Rect2(c + Vector2(-140.0, -58.0), Vector2(280.0, 92.0))
	HudStyle.slab(self, r, Color(HudStyle.INK, 0.72), 14.0, 2.5)
	HudStyle.text(self, Vector2(r.position.x, r.position.y + 32.0), "POPPED!", 30, HudStyle.AMMO, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var by := "by %s" % state.popped_by if state.popped_by != "" else "by the floor"
	if state.popped_with != "":
		by += " with %s" % state.popped_with
	HudStyle.text(self, Vector2(r.position.x, r.position.y + 54.0), by, 14, _name_color(state.popped_by_team), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	HudStyle.text(self, Vector2(r.position.x, r.position.y + 80.0), "back in %d" % ceili(state.respawn_in), 17, HudStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


# --- radar arrows (US-25.3) and hit direction (US-25.4) ---

func _draw_radar() -> void:
	if radar == null:
		return
	var c := size * 0.5
	var ring := radar.ring(size.y)
	for a in radar.visible():
		var p := c + a.dir * ring
		var side := Vector2(-a.dir.y, a.dir.x)
		var col: Color
		if a.enemy:
			# Enemy: a solid red arrowhead.
			col = Color(HudStyle.HIT, a.alpha)
			var pts := PackedVector2Array([p + a.dir * 10.0, p - a.dir * 6.0 + side * 8.0, p - a.dir * 6.0 - side * 8.0])
			var rim := PackedVector2Array([p + a.dir * 12.5, p - a.dir * 7.5 + side * 10.0, p - a.dir * 7.5 - side * 10.0])
			draw_colored_polygon(rim, Color(HudStyle.INK, a.alpha))
			draw_colored_polygon(pts, col)
		else:
			# Teammate: an open chevron in the team colour, so the two differ by shape too.
			col = Color(TeamPalette.color(state.my_team), a.alpha)
			var pts := PackedVector2Array([p - a.dir * 6.0 + side * 8.0, p + a.dir * 8.0, p - a.dir * 6.0 - side * 8.0])
			draw_polyline(pts, Color(HudStyle.INK, a.alpha), 6.0, true)
			draw_polyline(pts, col, 3.0, true)


func _draw_hits() -> void:
	var c := size * 0.5
	var ring := size.y * 0.26
	for h in _hits:
		var a: float = 1.0 - float(h.age) / HIT_LIFE
		var dir: Vector2 = h.dir
		var ang := dir.angle()
		draw_arc(c, ring, ang - 0.32, ang + 0.32, 16, Color(HudStyle.INK, 0.6 * a), 9.0, true)
		draw_arc(c, ring, ang - 0.3, ang + 0.3, 16, Color(HudStyle.HIT, 0.9 * a), 5.0, true)
		var tip := c + dir * (ring + 12.0)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip, c + dir * (ring + 2.0) + side * 7.0, c + dir * (ring + 2.0) - side * 7.0]), Color(HudStyle.HIT, 0.9 * a))
