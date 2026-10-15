class_name CombatView
extends Node2D
## Draws the fight from the match's combat state with the art lab's pieces: tracers, rockets,
## grenades, items on the floor, blasts, sparks and hits, spawn protection and health. Light
## (tracers, glows, sparks) is added on top (docs/art "Effects"). The toys themselves, their
## muzzle flashes and pops are `ToyView`'s.
##
## Reads `CombatSim` and its events; changes nothing (rule A1).

const PX := 1.0 / ArtAtlas.AUTHOR_PX_PER_U
## Tracer tail, u; and how far ahead of the body the gun's muzzle sits, so a tracer never
## starts inside the toy (bullets leave from the body origin).
const TRAIL := 46.0
const MUZZLE_REACH := 26.0
const TRACER_CORE := Color(1.0, 0.72, 0.3, 0.7)
const PROTECT := Color(0.55, 0.9, 1.0)
const HEALTH_BACK := Color(0.1, 0.08, 0.12, 0.75)
const HEALTH := Color(0.4, 0.9, 0.4)
const HEALTH_LOW := Color(0.95, 0.32, 0.25)
const OFFER := Color(1.0, 0.95, 0.75, 0.55)
const BLINK := Color(1.0, 0.25, 0.15)
const HIT_LIFE := 0.25
## Size of loose items on the floor, against their size in a hand.
const ITEM_SCALE := 0.9
## Health and battery packs read bigger than toy scale, so they are seen from afar.
const PACK_SCALE := 1.5
## Rocket smoke puffs per second.
const ROCKET_SMOKE := 30.0

var combat: CombatSim
var rules: Ruleset
## The local player's fighter, for the pickup offer and the respawn countdown.
var me: Fighter

var _atlas: ArtAtlas
var _light: Node2D
var _effects: Array[Dictionary] = []
var _clock: float = 0.0
## Last frame's bullets [pos, dir], to aim the sparks of an impact.
var _last_bullets: Array = []
var _smoke_debt: float = 0.0


func _init(combat_sim: CombatSim = null, local: Fighter = null) -> void:
	combat = combat_sim
	me = local
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_atlas = ArtLibrary.actors()
	_light = Node2D.new()
	_light.name = "Light"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = add
	_light.texture_filter = texture_filter
	_light.draw.connect(_draw_light)
	add_child(_light)
	if combat != null:
		rules = combat.rules
		combat.event.connect(_on_event)


func _on_event(e: Dictionary) -> void:
	var field := FxField.of(self)
	match e.type:
		&"blast":
			field.blast(e.pos, e.radius)
		&"hit":
			field.hit_flash((e.pos as Vector2) + Vector2(0, -8 if e.head else -2), e.head)
		&"blocked":
			var f := combat.fighter(e.toy)
			if f != null:
				_effects.append({"kind": &"blocked", "toy": e.toy, "age": 0.0, "life": HIT_LIFE})
		&"impact":
			field.sparks(e.pos, _impact_normal(e.pos))


func _impact_normal(at: Vector2) -> Vector2:
	var best := Vector2.UP
	var near := INF
	for b: Array in _last_bullets:
		var d := (b[0] as Vector2).distance_squared_to(at)
		if d < near:
			near = d
			best = -(b[1] as Vector2)
	return best


func sync(delta: float) -> void:
	_clock += delta
	for fx in _effects:
		fx.age += delta
	_effects = _effects.filter(func(fx: Dictionary) -> bool: return fx.age < fx.life)
	_last_bullets.clear()
	if combat != null:
		for b in combat.bullets:
			_last_bullets.append([b.pos, b.vel.normalized()])
		# Rockets smoke as they fly.
		if not combat.rockets.is_empty() and delta > 0.0:
			_smoke_debt += delta * ROCKET_SMOKE
			var field := FxField.of(self)
			while _smoke_debt >= 1.0:
				_smoke_debt -= 1.0
				for r in combat.rockets:
					var back := -r.vel.normalized()
					field.thrust_puff(r.pos + back * 12.0, back, Vector2.ZERO, 0.6)
	queue_redraw()
	_light.queue_redraw()


func _draw() -> void:
	if combat == null:
		return
	for it in combat.items:
		_draw_item(it)
	for b in combat.bullets:
		var dir := b.vel.normalized()
		var tail := minf(TRAIL, b.travelled - MUZZLE_REACH)
		if tail > 1.0:
			draw_line(b.pos - dir * tail, b.pos, Color(TRACER_CORE, TRACER_CORE.a * _bullet_alpha(b)), 0.9)
	for r in combat.rockets:
		_draw_rocket(r)
	for g in combat.grenades:
		var piece := ArtLibrary.weapon_piece(&"frag_grenade")
		var w := ArtLibrary.weapon(&"frag_grenade")
		var c := ArtLibrary.weapon_grip(w)
		draw_set_transform_matrix(Transform2D(g.age * 9.0, Vector2(PX, PX) * 0.8, 0.0, g.pos) * Transform2D(0.0, -c))
		_atlas.draw(self, piece)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for f in combat.fighters:
		if f.alive:
			_draw_fighter(f)


func _bullet_alpha(b: CombatSim.Bullet) -> float:
	var left := b.range - b.travelled
	return clampf(left / rules.bullet_fade, 0.0, 1.0) if rules.bullet_fade > 0.0 else 1.0


func _draw_light() -> void:
	if combat == null:
		return
	var tracer := ArtLibrary.fx_piece("tracer")
	var origin := _fx_origin(tracer)
	var tracer_len := _atlas.size_of(tracer).x * PX
	for b in combat.bullets:
		var tail := minf(TRAIL, b.travelled - MUZZLE_REACH)
		if tail <= 1.0:
			continue
		var sx := tail / tracer_len
		_light.draw_set_transform_matrix(Transform2D(b.vel.angle(), Vector2(sx * PX * 1.4, PX * 0.9), 0.0, b.pos) * Transform2D(0.0, -origin))
		_atlas.draw(_light, tracer, Vector2.ZERO, Color(1, 1, 1, _bullet_alpha(b)))
	var glow := ArtLibrary.fx_piece("muzzle_flash_glow")
	var go := _fx_origin(glow)
	for r in combat.rockets:
		var back := -r.vel.normalized()
		_light.draw_set_transform_matrix(Transform2D(0.0, Vector2(PX, PX) * 0.5, 0.0, r.pos + back * 8.0) * Transform2D(0.0, -go))
		_atlas.draw(_light, glow)
	for g in combat.grenades:
		var left := rules.frag_fuse - g.age
		if fmod(_clock * (4.0 if left > 0.6 else 12.0), 1.0) < 0.5:
			_light.draw_set_transform_matrix(Transform2D(0.0, Vector2(PX, PX) * 0.22, 0.0, g.pos + Vector2(0, -3)) * Transform2D(0.0, -go))
			_atlas.draw(_light, glow, Vector2.ZERO, BLINK)
	for it in combat.items:
		if me != null and me.offer == it.uid:
			_light.draw_set_transform_matrix(Transform2D(0.0, Vector2(0.45, 0.2) * PX, 0.0, it.pos + Vector2(0, -4)) * Transform2D(0.0, -go))
			_atlas.draw(_light, glow, Vector2.ZERO, OFFER)
	for f in combat.fighters:
		if f.alive and f.swing_left > 0.0:
			var ang := f.swing_dir.angle()
			_light.draw_set_transform_matrix(Transform2D.IDENTITY)
			_light.draw_arc(f.toy.position, 30.0, ang - 0.8, ang + 0.8, 12, Color(1, 1, 1, 0.6), 2.0)
	_light.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_rocket(r: CombatSim.Rocket) -> void:
	var w := ArtLibrary.weapon(&"rocket")
	var piece := ArtLibrary.weapon_piece(&"rocket")
	var rot := r.vel.angle()
	var xf := Transform2D(rot, Vector2(PX, PX), 0.0, r.pos) * Transform2D(0.0, -ArtLibrary.weapon_muzzle(w))
	# Flame out of the exhaust, pointing back.
	var flame := ArtLibrary.fx_piece("thrust_flame" if fmod(_clock * 30.0, 2.0) < 1.0 else "thrust_flame_b")
	var ex := xf * ArtLibrary._point(w, "exhaust")
	draw_set_transform_matrix(Transform2D(rot + PI * 0.5, Vector2(0.3, 0.45) * PX, 0.0, ex) * Transform2D(0.0, -_fx_origin(flame)))
	_atlas.draw(self, flame)
	draw_set_transform_matrix(xf)
	_atlas.draw(self, piece)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_item(it: CombatSim.FloorItem) -> void:
	var a := combat.item_alpha(it)
	var bob := sin(_clock * 3.0 + it.uid) * 1.2 if it.resting or it.point >= 0 else 0.0
	var at := it.pos + Vector2(0, -bob)
	var id := String(it.item)
	if ArtLibrary.pickups().has(id):
		var d: Dictionary = ArtLibrary.pickups()[id]
		var o := Vector2(float(d.origin[0]), float(d.origin[1]))
		draw_set_transform_matrix(Transform2D(0.0, Vector2(PX, PX) * PACK_SCALE, 0.0, at) * Transform2D(0.0, -o))
		_atlas.draw(self, StringName("pickups/" + id), Vector2.ZERO, Color(1, 1, 1, a))
	else:
		var wid := &"frag_grenade" if it.item == &"frag" else it.item
		var w := ArtLibrary.weapon(wid)
		if w.is_empty():
			return
		var size := _atlas.size_of(ArtLibrary.weapon_piece(wid))
		# Lying on the floor: bottom centre on the item's point.
		draw_set_transform_matrix(Transform2D(0.0, Vector2(PX, PX) * ITEM_SCALE, 0.0, at) * Transform2D(0.0, -Vector2(size.x * 0.5, size.y)))
		_atlas.draw(self, ArtLibrary.weapon_piece(wid), Vector2.ZERO, Color(1, 1, 1, a))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_fighter(f: Fighter) -> void:
	var t := f.toy
	var centre := t.position + Vector2(0, -4)
	# Spawn protection, always visible on the toy (US-22.3): a soft bubble.
	var blocked := 0.0
	for fx in _effects:
		if fx.kind == &"blocked" and fx.toy == f.id():
			blocked = maxf(blocked, 1.0 - fx.age / fx.life)
	if f.is_protected() or blocked > 0.0:
		var pulse := 0.55 + 0.25 * sin(_clock * 8.0) + blocked * 0.4
		draw_circle(centre, 30.0, Color(PROTECT, 0.1 + 0.15 * blocked))
		draw_arc(centre, 30.0, 0, TAU, 40, Color(PROTECT, pulse), 1.5 + 2.0 * blocked)
		draw_arc(centre + Vector2(-8, -10), 18.0, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.6 * pulse), 2.0)
	# Health, small, only once hurt.
	var share := clampf(t.health / rules.max_health, 0.0, 1.0)
	if share < 1.0:
		var top := t.position + Vector2(0, -(rules.head_height + rules.head_radius) - 12)
		var bar := Rect2(top + Vector2(-12, 0), Vector2(24, 2.5))
		draw_rect(bar.grow(0.75), HEALTH_BACK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), HEALTH if share > 0.3 else HEALTH_LOW)


func _fx_origin(piece: StringName) -> Vector2:
	var d: Dictionary = ArtLibrary.fx().get(String(piece).trim_prefix("fx/"), {})
	return Vector2(float(d.origin[0]), float(d.origin[1])) if d.has("origin") else Vector2.ZERO
