class_name ToyView
extends Node2D
## Draws one toy from its sim state, between the last two ticks: the art lab's cutout soldier,
## posed by `ToyAnimator` (US-41.2), its weapons at the grip (US-11.5), thrust and smoke from
## both battery nozzles against the push (US-03.1), the body lean (US-03.4), team colour on the
## batteries and wires with a pattern and a thin team outline (US-26.1, US-26.2), and the pop
## (US-15.1).
##
## Reads `SimToy`, its `Fighter` and combat events; changes nothing. The hitbox is the sim's
## (T-18); the art never changes it.

const HITBOX := Color(1.0, 0.1, 0.3)
const HITBOX_HEAD := Color(1.0, 0.85, 0.1)
const SHADOW := Color(0.08, 0.06, 0.1, 0.32)
## How far below the feet a contact shadow still shows, u.
const SHADOW_REACH := 90.0
## Thrust smoke puffs per second per nozzle at full thrust.
const PUFF_RATE := 9.0
const OUTLINE_WIDTH_U := 0.75
const PX := 1.0 / ArtAtlas.AUTHOR_PX_PER_U

var toy: SimToy
var rules: Ruleset
## The match's combat, for the toy's fighter and its events; may be null (movement only).
var combat: CombatSim:
	set(c):
		if combat != null and combat.event.is_connected(_on_event):
			combat.event.disconnect(_on_event)
		combat = c
		if combat != null:
			combat.event.connect(_on_event)
var show_hitboxes: bool = false
## A fighter to draw with when there is no combat (sheets, tests).
var fixed_fighter: Fighter
var animator: ToyAnimator
var frame: ToyAnimator.Frame

var _atlas: ArtAtlas
var _group: CanvasGroup
var _body: Node2D
var _glow: Node2D
var _front: Node2D
var _team: int = -99
var _team_color: Color = Color.WHITE
var _pattern: StringName = &""
var _flicker: float = 0.0
var _puff_debt: float = 0.0
var _was_thrusting: bool = false
var _last_pos: Vector2
var _vel: Vector2 = Vector2.ZERO
var _shadow_y: float = -1.0
var _shadow_k: float = 0.0


func _init(sim_toy: SimToy = null, ruleset: Ruleset = null, combat_sim: CombatSim = null) -> void:
	toy = sim_toy
	rules = ruleset
	z_index = 10
	_atlas = ArtLibrary.actors()
	animator = ToyAnimator.new(ToyRig.soldier(), ruleset)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_group = CanvasGroup.new()
	_group.name = "Outline"
	_group.fit_margin = 6.0
	_group.clear_margin = 6.0
	var mat := ShaderMaterial.new()
	mat.shader = TeamLook.outline_shader()
	_group.material = mat
	add_child(_group)
	_body = Node2D.new()
	_body.name = "Body"
	_body.draw.connect(_draw_body)
	_group.add_child(_body)
	_glow = Node2D.new()
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_front = Node2D.new()
	_front.name = "Debug"
	_front.draw.connect(_draw_debug)
	add_child(_front)
	if combat_sim != null:
		combat = combat_sim


func fighter() -> Fighter:
	if fixed_fighter != null:
		return fixed_fighter
	return combat.fighter(toy.toy_id) if combat != null else null


func sync(alpha: float, delta: float) -> void:
	var at := toy.prev_position.lerp(toy.position, alpha)
	if delta > 0.0:
		_vel = _vel.lerp((at - _last_pos) / delta, clampf(delta * 20.0, 0.0, 1.0))
	if (at - _last_pos).length() > 200.0:
		_vel = toy.velocity
	_last_pos = at
	position = at
	var f := fighter()
	_set_team(f.team if f != null else Fighter.NO_TEAM)
	frame = animator.update(toy, f, toy.velocity, delta)
	_flicker += delta * 30.0
	if toy.active and delta > 0.0:
		_emit_smoke(delta)
	_update_shadow()
	queue_redraw()
	_body.queue_redraw()
	_glow.queue_redraw()
	_front.queue_redraw()


func _set_team(team: int) -> void:
	if team == _team:
		return
	_team = team
	_team_color = TeamLook.battery_color(team)
	_pattern = TeamLook.pattern_piece(team)
	var mat := _group.material as ShaderMaterial
	mat.set_shader_parameter("outline_color", TeamLook.outline_color(team))
	# The outline is a world width; the shader takes screen pixels.
	mat.set_shader_parameter("width", OUTLINE_WIDTH_U * ArtAtlas.texels_per_u)


func _on_event(e: Dictionary) -> void:
	var mine: bool = e.get("toy", -1) == toy.toy_id
	match e.type:
		&"shot":
			if mine and frame != null:
				animator.kick(bool(e.get("off_hand", false)))
				var i := 1 if bool(e.get("off_hand", false)) and frame.muzzles.size() > 1 else 0
				if i < frame.muzzles.size():
					var big := 1.4 if e.weapon in [&"rocket_launcher", &"pump_shotgun", &"sniper_rifle"] else 1.0
					FxField.of(self).muzzle_flash(global_transform * frame.muzzles[i], big)
		&"hit":
			if mine:
				var a := combat.fighter(e.get("attacker", 0))
				var from_x := toy.position.x + 1.0
				if a != null and a.toy != toy:
					from_x = a.toy.position.x
				animator.flinch(from_x, toy.position.x)
		&"pop":
			if mine:
				_pop()
			elif e.get("killer", -1) == toy.toy_id:
				animator.scored()


func _emit_smoke(delta: float) -> void:
	var thrusting := toy.thrust > 0.0
	var field := FxField.of(self)
	if thrusting and not _was_thrusting and frame != null:
		for n in frame.nozzles:
			field.smoke_ring(to_global(n), frame.thrust_dir)
	_was_thrusting = thrusting
	if not thrusting or frame == null:
		return
	_puff_debt += delta * PUFF_RATE * (0.4 + 0.6 * toy.thrust)
	while _puff_debt >= 1.0:
		_puff_debt -= 1.0
		for n in frame.nozzles:
			field.thrust_puff(to_global(n) + frame.thrust_dir * 10.0, frame.thrust_dir, _vel, toy.thrust)


func _update_shadow() -> void:
	_shadow_k = 0.0
	if not is_inside_tree() or not toy.active:
		return
	var feet := global_position + Vector2(0, -rules.body_bottom)
	var q := PhysicsRayQueryParameters2D.create(feet + Vector2(0, -2), feet + Vector2(0, SHADOW_REACH), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.normal.y > -0.5:
		return
	var d: float = hit.position.y - feet.y
	_shadow_y = hit.position.y - global_position.y
	_shadow_k = clampf(1.0 - d / SHADOW_REACH, 0.0, 1.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if toy == null or frame == null:
		return
	# Contact shadow on whatever is under the feet, smaller and lighter the higher the toy.
	if _shadow_k > 0.0:
		var w := 15.0 * (0.55 + 0.45 * _shadow_k)
		draw_set_transform(Vector2(0, _shadow_y), 0.0, Vector2(1.0, 0.26))
		draw_circle(Vector2.ZERO, w, Color(SHADOW, SHADOW.a * _shadow_k))
		draw_circle(Vector2.ZERO, w * 0.62, Color(SHADOW, SHADOW.a * _shadow_k * 0.8))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	# Thrust flames from both nozzles, under the body, along the push (US-03.1).
	if toy.thrust > 0.0:
		var piece := ArtLibrary.fx_piece("thrust_flame" if fmod(_flicker, 2.0) < 1.0 else "thrust_flame_b")
		var origin := _fx_origin(piece)
		var len := (0.7 + 0.6 * toy.thrust) * (0.88 + 0.12 * sin(_flicker * 1.7))
		for i in frame.nozzles.size():
			var n: Vector2 = frame.nozzles[i]
			var rot := frame.thrust_dir.angle() - PI * 0.5
			var s := Vector2(0.7, len * (1.0 if i == 0 else 0.9)) * PX
			draw_set_transform_matrix(Transform2D(rot, s, 0.0, n) * Transform2D(0.0, -origin))
			_atlas.draw(self, piece)
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_body() -> void:
	if frame == null:
		return
	for it: Array in frame.items:
		var piece: StringName = it[0]
		var xf: Transform2D = it[1]
		var mod: Color = it[2]
		_body.draw_set_transform_matrix(xf)
		if it[3] == &"jetpack_team":
			if _pattern == &"baked":
				_atlas.draw(_body, TeamLook.baked_piece(_team))
			else:
				_atlas.draw(_body, piece, Vector2.ZERO, _team_color)
				if _pattern != &"":
					_atlas.draw(_body, _pattern)
		else:
			_atlas.draw(_body, piece, Vector2.ZERO, mod)
	_body.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_glow() -> void:
	if frame == null or toy.thrust <= 0.0:
		return
	var piece := ArtLibrary.fx_piece("thrust_glow")
	var origin := _fx_origin(piece)
	var s := (0.35 + 0.3 * toy.thrust) * (0.9 + 0.1 * sin(_flicker * 2.3))
	var mid := (frame.nozzles[0] + frame.nozzles[frame.nozzles.size() - 1]) * 0.5
	_glow.draw_set_transform_matrix(Transform2D(frame.thrust_dir.angle() - PI * 0.5, Vector2(s, s) * PX, 0.0, mid) * Transform2D(0.0, -origin))
	_atlas.draw(_glow, piece, Vector2.ZERO, Color(1, 1, 1, 0.85))
	_glow.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_debug() -> void:
	if not show_hitboxes:
		return
	for cs: CollisionShape2D in toy.hit_shapes():
		if cs.shape is CircleShape2D:
			_front.draw_arc(cs.position, (cs.shape as CircleShape2D).radius, 0.0, TAU, 32, HITBOX_HEAD, 1.0)
		else:
			var r := cs.shape.get_rect()
			r.position += cs.position
			_front.draw_rect(r, HITBOX, false, 1.0)
	_front.draw_circle(Vector2.ZERO, 1.5, HITBOX)


func _fx_origin(piece: StringName) -> Vector2:
	var d: Dictionary = ArtLibrary.fx().get(String(piece).trim_prefix("fx/"), {})
	return Vector2(float(d.origin[0]), float(d.origin[1])) if d.has("origin") else Vector2.ZERO


# ---------------------------------------------------------------- the pop

## Plastic snaps at the joints: every part flies off from where it was, the helmet highest,
## with a snap at each joint and a comic POP! (US-15.1, docs/art ref 11).
func _pop() -> void:
	if frame == null:
		return
	var field := FxField.of(self)
	var g := global_transform
	var centre := g * Vector2(0, -6)
	# Parts drawn on one another (face on head, the jetpack's layers) fly as one.
	var together := {&"face": &"head", &"jetpack_team": &"jetpack_back", &"jetpack_front": &"jetpack_back"}
	var motion := {}
	for it: Array in frame.items:
		var piece: StringName = it[0]
		var name: StringName = it[3]
		var mod: Color = it[2]
		if name == &"jetpack_team":
			piece = TeamLook.baked_piece(_team)
			mod = Color.WHITE
		var xf: Transform2D = g * (it[1] as Transform2D)
		var c := xf * (_atlas.size_of(piece) * 0.5)
		var away := (c - centre).normalized() if (c - centre).length() > 0.5 else Vector2.UP
		var key: StringName = together.get(name, name)
		if not motion.has(key):
			var v := away * randf_range(120.0, 240.0) + Vector2(randf_range(-40, 40), -randf_range(140.0, 260.0)) + _vel * 0.3
			var spin := randf_range(-12.0, 12.0)
			if name == &"helmet":
				v = Vector2(randf_range(-60, 60), -420.0)
				spin *= 1.6
			motion[key] = [v, spin, 1.6 + randf() * 0.5 + (0.6 if name == &"helmet" else 0.0)]
		var m: Array = motion[key]
		if name == &"face":
			piece = animator.rig.faces.get(&"shocked", piece)
		var p := field.spawn_xf(piece, xf, m[2])
		p.tint = mod
		p.vel = m[0]
		p.spin = m[1]
		p.gravity = 520.0
		p.collide = true
		p.fade = 0.3
	for j in frame.joints:
		var s := field.spawn(ArtLibrary.fx_piece("pop_snap"), g * j, randf() * TAU, 0.7 + randf() * 0.3, 0.28)
		s.grow = 2.0
		s.fade = 0.6
	var burst := field.spawn(ArtLibrary.fx_piece("pop_burst"), centre + Vector2(0, -34), randf_range(-0.2, 0.2), 1.1, 0.8)
	burst.grow = 0.7
	burst.fade = 0.35
	var word := field.spawn(ArtLibrary.fx_piece("pop_text"), centre + Vector2(0, -34), randf_range(-0.18, 0.08), 1.05, 0.9)
	word.grow = 0.5
	word.fade = 0.3
	word.vel = Vector2(0, -16)
	var flash := field.spawn(ArtLibrary.fx_piece("frag_blast_glow"), centre, 0.0, 0.6, 0.25)
	flash.fade = 0.8
