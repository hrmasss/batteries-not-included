class_name FxField
extends Node2D
## World-space effects drawn from the actors sheet: smoke, sparks, blasts, the pop's flying parts
## and its POP!. Two layers: hot shapes drawn as they are, and light added on top (`blend: add`
## in fx.json), so glow keeps on any map (docs/art "Effects").
##
## One per game view; toy views and the combat view find it with `FxField.of()`. Particles are
## plain data, stepped and drawn here, so a whole field is two canvas items.

const GROUP := &"bni_fx_field"
const MAX_PARTICLES := 600
const PX := 1.0 / ArtAtlas.AUTHOR_PX_PER_U

## One drawn piece. `xf` draws its image (author px) in world space; it moves by `vel` and
## turns by `spin` (radians/s) about its centre, grows by `grow` (per second, multiplicative).
class P:
	var piece: StringName
	var xf: Transform2D
	var vel: Vector2
	var spin: float = 0.0
	var grow: float = 0.0
	var gravity: float = 0.0
	var drag: float = 0.0
	var age: float = 0.0
	var life: float = 1.0
	## Alpha at birth; fades out over the last `fade` share of its life.
	var alpha: float = 1.0
	var fade: float = 0.5
	## 0 to 1 of life spent fading in.
	var fade_in: float = 0.0
	var tint: Color = Color.WHITE
	var additive: bool = false
	## Bounces off terrain (the pop's parts).
	var collide: bool = false
	var bounce: float = 0.35
	var resting: bool = false


var atlas: ArtAtlas
var particles: Array[P] = []
var _add_layer: Node2D
var _paused_for_test: bool = false


static func of(node: Node) -> FxField:
	var tree := node.get_tree()
	if tree != null:
		var found := tree.get_first_node_in_group(GROUP)
		if found is FxField:
			return found
	var f := FxField.new()
	f.name = "FxField"
	var host := node.get_parent() if node.get_parent() != null else node
	host.add_child(f)
	return f


func _init() -> void:
	z_index = 40
	add_to_group(GROUP)
	atlas = ArtLibrary.actors()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_add_layer = Node2D.new()
	_add_layer.name = "Light"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer.material = mat
	_add_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_add_layer.draw.connect(_draw_layer.bind(true))
	add_child(_add_layer)


## A piece at `pos`, origin from fx.json (or the piece's centre), rotated and scaled.
func spawn(piece: StringName, pos: Vector2, rot: float = 0.0, scale: float = 1.0, life: float = 0.5) -> P:
	var p := P.new()
	p.piece = piece
	p.life = life
	var origin := _origin(piece)
	p.xf = Transform2D(rot, Vector2(scale, scale) * PX, 0.0, pos) * Transform2D(0.0, -origin)
	p.additive = _is_add(piece)
	if particles.size() >= MAX_PARTICLES:
		particles.pop_front()
	particles.append(p)
	return p


## A piece drawn with a given image transform (the pop's parts keep their pose).
func spawn_xf(piece: StringName, xf: Transform2D, life: float) -> P:
	var p := P.new()
	p.piece = piece
	p.xf = xf
	p.life = life
	p.additive = _is_add(piece)
	if particles.size() >= MAX_PARTICLES:
		particles.pop_front()
	particles.append(p)
	return p


func _origin(piece: StringName) -> Vector2:
	var id := String(piece).trim_prefix("fx/")
	var d: Dictionary = ArtLibrary.fx().get(id, {})
	if d.has("origin"):
		return Vector2(float(d.origin[0]), float(d.origin[1]))
	return atlas.size_of(piece) * 0.5


func _is_add(piece: StringName) -> bool:
	var id := String(piece).trim_prefix("fx/")
	return ArtLibrary.fx().get(id, {}).get("blend", "normal") == "add"


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if particles.is_empty():
		return
	var space: PhysicsDirectSpaceState2D = null
	var keep: Array[P] = []
	for p in particles:
		p.age += delta
		if p.age >= p.life:
			continue
		if not p.resting:
			p.vel.y += p.gravity * delta
			if p.drag > 0.0:
				p.vel *= exp(-p.drag * delta)
			var c := p.xf * (atlas.size_of(p.piece) * 0.5)
			var move := p.vel * delta
			if p.collide and move.length_squared() > 0.0:
				if space == null and is_inside_tree():
					space = get_world_2d().direct_space_state
				if space != null:
					var q := PhysicsRayQueryParameters2D.create(c, c + move, 1)
					var hit := space.intersect_ray(q)
					if not hit.is_empty():
						var n: Vector2 = hit.normal
						p.vel = p.vel.bounce(n) * p.bounce
						p.spin *= 0.6
						move = (hit.position - c) + n * 0.5
						if p.vel.length() < 25.0 and n.y < -0.5:
							p.resting = true
							p.vel = Vector2.ZERO
							p.spin = 0.0
			var turn := Transform2D(p.spin * delta, Vector2.ZERO)
			var g := 1.0 + p.grow * delta
			p.xf = Transform2D(0.0, c + move) * turn * Transform2D(0.0, Vector2(g, g), 0.0, Vector2.ZERO) * Transform2D(0.0, -c) * p.xf
		keep.append(p)
	particles = keep
	queue_redraw()
	_add_layer.queue_redraw()


func _draw() -> void:
	_draw_layer(false)


func _draw_layer(additive: bool) -> void:
	var ci: CanvasItem = _add_layer if additive else self
	for p in particles:
		if p.additive != additive:
			continue
		var k := p.age / p.life
		var a := p.alpha
		if p.fade_in > 0.0 and k < p.fade_in:
			a *= k / p.fade_in
		if k > 1.0 - p.fade:
			a *= clampf((1.0 - k) / p.fade, 0.0, 1.0)
		ci.draw_set_transform_matrix(p.xf)
		atlas.draw(ci, p.piece, Vector2.ZERO, Color(p.tint, p.tint.a * a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- effect recipes

## Muzzle flash at a muzzle frame (x along the barrel). `big` for heavy guns.
func muzzle_flash(m: Transform2D, big: float = 1.0) -> void:
	var piece := ArtLibrary.fx_piece("muzzle_flash" if randf() < 0.5 else "muzzle_flash_b")
	var s := 0.85 * big
	var p := spawn_xf(piece, m * Transform2D(0.0, Vector2(s, s * (0.8 + randf() * 0.4)) * PX, 0.0, Vector2.ZERO) * Transform2D(0.0, -_origin(piece)), 0.06)
	p.fade = 0.4
	var g := spawn_xf(ArtLibrary.fx_piece("muzzle_flash_glow"), m * Transform2D(0.0, Vector2(s, s) * PX, 0.0, Vector2.ZERO) * Transform2D(0.0, -_origin(ArtLibrary.fx_piece("muzzle_flash_glow"))), 0.09)
	g.fade = 0.7


## Sparks where a bullet stops: short streaks of light thrown back along the normal.
func sparks(pos: Vector2, normal: Vector2, count: int = 5, heat: float = 1.0) -> void:
	for i in count:
		var dir := normal.rotated(randf_range(-1.1, 1.1))
		var p := spawn(ArtLibrary.fx_piece("tracer"), pos, dir.angle() + PI, 0.22 + randf() * 0.12, 0.12 + randf() * 0.12)
		p.vel = dir * randf_range(80.0, 220.0) * heat
		p.gravity = 300.0
		p.drag = 4.0
		p.fade = 0.6
	var puff := spawn(ArtLibrary.fx_piece("smoke_puff"), pos, randf() * TAU, 0.3, 0.35)
	puff.vel = normal * 20.0
	puff.grow = 1.5
	puff.alpha = 0.5
	puff.fade = 0.8


## A hit on a toy: a white pop of light and plastic-coloured chips.
func hit_flash(pos: Vector2, head: bool) -> void:
	var g := spawn(ArtLibrary.fx_piece("muzzle_flash_glow"), pos, randf() * TAU, 0.6 if head else 0.45, 0.1)
	g.fade = 0.8
	sparks(pos, Vector2.UP, 4 if head else 3, 0.8)


## A frag or rocket blast (T-63 radius): fireball, light, smoke, sparks.
func blast(pos: Vector2, radius: float) -> void:
	var s := radius / 125.0
	var fire := spawn(ArtLibrary.fx_piece("frag_blast"), pos, randf_range(-0.3, 0.3), 1.2 * s, 0.42)
	fire.grow = 1.4
	fire.fade = 0.55
	var glow := spawn(ArtLibrary.fx_piece("frag_blast_glow"), pos, 0.0, 2.6 * s, 0.5)
	glow.grow = 0.8
	glow.fade = 0.8
	for i in 6:
		var dir := Vector2.from_angle(randf() * TAU)
		var sm := spawn(ArtLibrary.fx_piece("blast_smoke"), pos + dir * 12.0 * s, randf() * TAU, (0.8 + randf() * 0.5) * s, 1.4 + randf() * 0.6)
		sm.vel = dir * 70.0 * s + Vector2(0, -25)
		sm.drag = 2.2
		sm.grow = 0.35
		sm.alpha = 0.85
		sm.fade = 0.6
		sm.fade_in = 0.12
	for i in 14:
		var dir := Vector2.from_angle(randf() * TAU)
		var sp := spawn(ArtLibrary.fx_piece("tracer"), pos, dir.angle() + PI, 0.3 + randf() * 0.2, 0.25 + randf() * 0.2)
		sp.vel = dir * randf_range(200.0, 420.0) * s
		sp.gravity = 260.0
		sp.drag = 3.0
		sp.fade = 0.5


## Thrust smoke: a puff that drifts out of the nozzle along the thrust and rises.
func thrust_puff(pos: Vector2, dir: Vector2, toy_vel: Vector2, strength: float) -> void:
	var p := spawn(ArtLibrary.fx_piece("smoke_puff"), pos + dir * 6.0, randf() * TAU, 0.5 + 0.2 * strength, 0.7 + randf() * 0.3)
	p.vel = dir * (60.0 + 50.0 * strength) + toy_vel * 0.25 + Vector2(0, -12)
	p.drag = 3.0
	p.grow = 1.2
	p.spin = randf_range(-2.0, 2.0)
	p.alpha = 0.42
	p.fade = 0.75
	p.fade_in = 0.1


## The smoke ring a toy leaves when its jetpack kicks in.
func smoke_ring(pos: Vector2, dir: Vector2) -> void:
	var p := spawn(ArtLibrary.fx_piece("smoke_ring"), pos + dir * 8.0, dir.angle() - PI * 0.5, 0.55, 0.6)
	p.vel = dir * 70.0
	p.drag = 3.5
	p.grow = 1.8
	p.alpha = 0.85
	p.fade = 0.7
