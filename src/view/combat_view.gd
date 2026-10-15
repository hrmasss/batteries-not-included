class_name CombatView
extends Node2D
## Draws the fight from the match's combat state: bullets, rockets, grenades, items on the
## floor, blasts, pops, hits, health bars, team marks and spawn protection. Placeholder shapes
## and lines until the art task replaces them.
##
## Reads `CombatSim` and its events; changes nothing (rule A1).

const BULLET := Color(1.0, 0.92, 0.45)
const ROCKET := Color(0.95, 0.45, 0.2)
const GRENADE := Color(0.35, 0.55, 0.2)
const GRENADE_BLINK := Color(1.0, 0.25, 0.2)
const BLAST := Color(1.0, 0.6, 0.15)
const BLAST_CORE := Color(1.0, 0.95, 0.7)
const POP := Color(1.0, 0.95, 0.3)
const HIT := Color(1.0, 1.0, 1.0)
const BLOCKED := Color(0.45, 0.9, 1.0)
const PROTECT := Color(0.45, 0.9, 1.0)
const HEALTH_BACK := Color(0.1, 0.1, 0.1, 0.8)
const HEALTH := Color(0.35, 0.9, 0.35)
const HEALTH_LOW := Color(0.95, 0.3, 0.25)
const OFFER := Color(1.0, 1.0, 1.0)
const TEXT := Color(1.0, 1.0, 1.0)
const TEXT_SHADOW := Color(0.0, 0.0, 0.0, 0.7)
## Team colours by team number; 0 (no team) draws no team mark.
const TEAMS := [Color(0, 0, 0, 0), Color(0.3, 0.55, 1.0), Color(1.0, 0.55, 0.15), Color(0.85, 0.3, 0.85), Color(0.3, 0.85, 0.75)]
const ITEM_COLOURS := {
	&"frag": Color(0.35, 0.55, 0.2),
	&"health_pack": Color(0.9, 0.25, 0.25),
	&"battery_pack": Color(0.95, 0.75, 0.15),
}
const WEAPON_ITEM := Color(0.55, 0.55, 0.6)

## Drawn bullet trail, u.
const TRAIL := 70.0
## How long effects stay on screen, s.
const BLAST_LIFE := 0.45
const POP_LIFE := 0.9
const HIT_LIFE := 0.15
const FLASH_LIFE := 0.06
const FONT_SIZE := 10

var combat: CombatSim
var rules: Ruleset
## The local player's fighter, for the pickup offer and the respawn countdown.
var me: Fighter

var _effects: Array[Dictionary] = []
var _clock: float = 0.0


func _init(combat_sim: CombatSim = null, local: Fighter = null) -> void:
	combat = combat_sim
	me = local
	z_index = 20
	if combat != null:
		rules = combat.rules
		combat.event.connect(_on_event)


func _on_event(e: Dictionary) -> void:
	match e.type:
		&"blast":
			_effects.append({"kind": &"blast", "pos": e.pos, "radius": e.radius, "age": 0.0, "life": BLAST_LIFE})
		&"pop":
			_effects.append({"kind": &"pop", "pos": e.pos, "age": 0.0, "life": POP_LIFE})
		&"hit":
			_effects.append({"kind": &"hit", "pos": e.pos, "age": 0.0, "life": HIT_LIFE, "head": e.head})
		&"blocked":
			var f := combat.fighter(e.toy)
			if f != null:
				_effects.append({"kind": &"blocked", "pos": f.toy.position, "age": 0.0, "life": HIT_LIFE})
		&"impact":
			_effects.append({"kind": &"impact", "pos": e.pos, "age": 0.0, "life": HIT_LIFE})
		&"shot":
			var f := combat.fighter(e.toy)
			if f != null:
				_effects.append({"kind": &"flash", "toy": e.toy, "dir": e.dir, "age": 0.0, "life": FLASH_LIFE})


func sync(delta: float) -> void:
	_clock += delta
	for fx in _effects:
		fx.age += delta
	_effects = _effects.filter(func(fx: Dictionary) -> bool: return fx.age < fx.life)
	queue_redraw()


func _draw() -> void:
	if combat == null:
		return
	var font := ThemeDB.fallback_font
	for it in combat.items:
		_draw_item(it, font)
	for b in combat.bullets:
		var dir := b.vel.normalized()
		var left := b.range - b.travelled
		var a := clampf(left / rules.bullet_fade, 0.0, 1.0) if rules.bullet_fade > 0.0 else 1.0
		draw_line(b.pos - dir * TRAIL, b.pos, Color(BULLET, a), 2.5)
	for r in combat.rockets:
		var dir := r.vel.normalized()
		draw_line(r.pos - dir * 14.0, r.pos, ROCKET, 4.0)
		draw_circle(r.pos, 2.5, BLAST_CORE)
	for g in combat.grenades:
		var left := rules.frag_fuse - g.age
		var blink := fmod(_clock * (4.0 if left > 0.6 else 12.0), 1.0) < 0.5
		draw_circle(g.pos, 3.5, GRENADE_BLINK if blink else GRENADE)
	for f in combat.fighters:
		if f.alive:
			_draw_fighter(f, font)
	for fx in _effects:
		_draw_effect(fx, font)
	if me != null and not me.alive:
		var who := combat.fighter(me.popped_by)
		var by := "yourself" if who == me or who == null else "toy %d" % me.popped_by
		var line := "POPPED by %s with %s   respawn in %d" % [by, String(me.popped_with).replace("_", " "), ceili(me.respawn_left)]
		_text(font, me.toy.position + Vector2(-90, -50), line, TEXT)


func _draw_item(it: CombatSim.FloorItem, font: Font) -> void:
	var a := combat.item_alpha(it)
	var c: Color = ITEM_COLOURS.get(it.item, WEAPON_ITEM)
	var box := Rect2(it.pos + Vector2(-9, -12), Vector2(18, 12))
	draw_rect(box, Color(c, a))
	draw_rect(box, Color(0, 0, 0, a), false, 1.0)
	var label := String(it.item).replace("_", " ")
	_text(font, it.pos + Vector2(-label.length() * 2.6, -16), label, Color(TEXT, a))
	if me != null and me.offer == it.uid:
		draw_rect(box.grow(3.0), Color(OFFER, a), false, 1.5)


func _draw_fighter(f: Fighter, font: Font) -> void:
	var t := f.toy
	var top := t.position + Vector2(0, -(rules.head_height + rules.head_radius) - 8)
	# Team mark: a thin ring in the team colour (US-26 does the real one).
	if f.team > 0:
		draw_arc(t.position + Vector2(0, -4), 26.0, 0, TAU, 32, TEAMS[f.team % TEAMS.size()], 1.5)
	# Spawn protection, always visible on the toy (US-22.3).
	if f.is_protected():
		var pulse := 0.6 + 0.4 * sin(_clock * 10.0)
		draw_arc(t.position + Vector2(0, -4), 30.0, 0, TAU, 40, Color(PROTECT, pulse), 2.5)
		draw_circle(t.position + Vector2(0, -4), 30.0, Color(PROTECT, 0.12))
	# Health bar.
	var share := clampf(t.health / rules.max_health, 0.0, 1.0)
	var bar := Rect2(top + Vector2(-14, 0), Vector2(28, 3))
	draw_rect(bar, HEALTH_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), HEALTH if share > 0.3 else HEALTH_LOW)
	# Weapon and ammo, small, under the toy.
	var w := f.main_weapon()
	if w != null:
		var line := "%s %d/%d" % [w.def.display_name, w.mag, w.reserve]
		if w.reloading():
			line = "%s reloading" % w.def.display_name
		var off := f.off_weapon()
		if off != null:
			line += "  + %s %d/%d" % [off.def.display_name, off.mag, off.reserve]
		_text(font, t.position + Vector2(-30, 26), line, TEXT)
	# Melee swing arc.
	if f.swing_left > 0.0:
		var ang := f.swing_dir.angle()
		draw_arc(t.position, 30.0, ang - 0.8, ang + 0.8, 12, HIT, 2.0)


func _draw_effect(fx: Dictionary, font: Font) -> void:
	var k: float = fx.age / fx.life
	match fx.kind:
		&"blast":
			var r: float = fx.radius * (0.35 + 0.65 * k)
			draw_circle(fx.pos, r, Color(BLAST, 0.45 * (1.0 - k)))
			draw_circle(fx.pos, r * 0.45, Color(BLAST_CORE, 0.8 * (1.0 - k)))
			draw_arc(fx.pos, fx.radius, 0, TAU, 48, Color(BLAST, 0.5 * (1.0 - k)), 1.0)
		&"pop":
			for i in 10:
				var dir := Vector2.RIGHT.rotated(i * TAU / 10.0)
				draw_line(fx.pos + dir * (8.0 + 30.0 * k), fx.pos + dir * (16.0 + 46.0 * k), Color(POP, 1.0 - k), 2.5)
			_text(font, fx.pos + Vector2(-14, -28 - 20 * k), "POP!", Color(POP, 1.0 - k), 16)
		&"hit":
			draw_circle(fx.pos, 6.0 * (1.0 - k) + 2.0, Color(HIT if not fx.head else POP, 1.0 - k))
		&"blocked":
			draw_arc(fx.pos + Vector2(0, -4), 30.0, 0, TAU, 40, Color(BLOCKED, 1.0 - k), 4.0)
		&"impact":
			draw_circle(fx.pos, 3.0, Color(BULLET, 1.0 - k))
		&"flash":
			var f := combat.fighter(fx.toy)
			if f != null and f.alive:
				var at: Vector2 = f.toy.position + (fx.dir as Vector2) * 18.0
				draw_circle(at, 5.0, Color(BLAST_CORE, 1.0 - k))


func _text(font: Font, at: Vector2, s: String, c: Color, size: int = FONT_SIZE) -> void:
	draw_string(font, at + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(TEXT_SHADOW, c.a * TEXT_SHADOW.a))
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
