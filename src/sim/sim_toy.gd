class_name SimToy
extends CharacterBody2D
## One toy as the match server sees it: its body, its hitbox and its movement state.
##
## No drawing and no input here; the view reads this state and draws it. Every toy type shares
## this one body (US-04.1, rule A9): `toy_type` is cosmetic and nothing in the sim reads it.
##
## World space is Godot's 2D space: x right, y DOWN, 1 unit = 1 u. `position` is the body
## origin of the classic's hitbox (T-18); the feet are `-rules.body_bottom` below it.
## Stick and intent vectors are y up (see `InputIntent`).

enum Mode { STANDING, WALKING, CROUCHED, AIRBORNE, FLYING }

const TERRAIN_LAYER := 1
const TOY_LAYER := 2
## Collision solver settings. Not tuning: they decide how contacts are found, not how they feel.
const SAFE_MARGIN := 0.08
const SLIDE_ITERATIONS := 4
const FLOOR_NORMAL_Y := -0.5
const PROBE_DISTANCE := 0.5

var toy_id: int = 0
## Cosmetic family (plastic soldier, plush, tin robot...). Never read by the rules.
var toy_type: StringName = &"plastic_soldier"

var health: float = 0.0
var battery: float = 0.0
var battery_max: float = 0.0
var jetpack_on: bool = false
## 0 to 1: how hard the jetpack pushes this tick. Drives the drain and the flame.
var thrust: float = 0.0
var airtime: float = 0.0
var since_thrust: float = 1000.0
var since_jump: float = 1000.0
var since_foot: float = 1000.0
var foot_contact: bool = false
var crouched: bool = false
var crouch_timer: float = 0.0
## Last aim or move direction with any sideways part, y up. Read by the view for facing and lean.
var facing: Vector2 = Vector2.RIGHT
## The move stick this tick, y up, for the view's lean.
var stick: Vector2 = Vector2.ZERO
var stick_held: bool = false
## Primary and off-hand weapon weights (T-19). Empty means bare hands: weight 1.
var weapon_weights: PackedFloat32Array = []
## Total sim time this toy flew with thrust, for drills and tests.
var flight_time: float = 0.0

## Position before the last tick, for drawing between ticks.
var prev_position: Vector2 = Vector2.ZERO

var _body_shape: CollisionShape2D
var _head_shape: CollisionShape2D
var _crouch_shape: CollisionShape2D


## Builds the shared hitbox from the ruleset (T-18).
func build(rules: Ruleset) -> void:
	collision_layer = 1 << (TOY_LAYER - 1)
	collision_mask = 1 << (TERRAIN_LAYER - 1)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_body_shape = _add_box("Body", rules.body_width, rules.body_bottom, rules.body_top)
	_head_shape = CollisionShape2D.new()
	_head_shape.name = "Head"
	var circle := CircleShape2D.new()
	circle.radius = rules.head_radius
	_head_shape.shape = circle
	_head_shape.position = Vector2(0.0, -rules.head_height)
	add_child(_head_shape)
	_crouch_shape = _add_box("Crouch", rules.crouch_width, rules.crouch_bottom, rules.crouch_top)
	_crouch_shape.disabled = true
	health = rules.max_health


func _add_box(shape_name: String, width: float, bottom: float, top: float) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	cs.name = shape_name
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, top - bottom)
	cs.shape = rect
	cs.position = Vector2(0.0, -(top + bottom) * 0.5)
	add_child(cs)
	return cs


func set_crouched(on: bool) -> void:
	if crouched == on:
		return
	crouched = on
	_head_shape.disabled = on
	_crouch_shape.disabled = not on


## The shapes that take hits right now, in toy-local space (US-01.6, US-04.3).
func hit_shapes() -> Array[CollisionShape2D]:
	var out: Array[CollisionShape2D] = []
	for cs: CollisionShape2D in [_body_shape, _head_shape, _crouch_shape]:
		if not cs.disabled:
			out.append(cs)
	return out


## World-space box around every live hit shape.
func hit_bounds() -> Rect2:
	var box := Rect2()
	var first := true
	for cs: CollisionShape2D in hit_shapes():
		var r := cs.shape.get_rect()
		r.position += cs.position + position
		box = r if first else box.merge(r)
		first = false
	return box


## T-19: primary × (off-hand × (1 − share) + share).
func weight_factor(rules: Ruleset) -> float:
	var primary := weapon_weights[0] if weapon_weights.size() > 0 else 1.0
	var off := weapon_weights[1] if weapon_weights.size() > 1 else 1.0
	var share := rules.offhand_weight_share
	return primary * (off * (1.0 - share) + share)


func mode() -> Mode:
	if jetpack_on and stick_held and battery > 0.0:
		return Mode.FLYING
	if crouched:
		return Mode.CROUCHED
	if not foot_contact:
		return Mode.AIRBORNE
	if stick_held and absf(stick.x) > 0.0:
		return Mode.WALKING
	return Mode.STANDING


func mode_name() -> String:
	return String(Mode.keys()[mode()]).to_lower()


func speed() -> float:
	return velocity.length()


## Moves the body for one physics sub-step: `velocity` × `h`, sliding along terrain. Contacts
## bounce and rub by toy × terrain, the way the classic's physics combines them.
func move_substep(h: float, bounce: float, friction: float, rules: Ruleset) -> void:
	var e := bounce * rules.terrain_bounce
	var u := friction * rules.terrain_friction
	var motion := velocity * h
	var floor_hit := false
	for i in SLIDE_ITERATIONS:
		if motion.length_squared() < 1e-12:
			break
		var col := move_and_collide(motion, false, SAFE_MARGIN, true)
		if col == null:
			break
		var n := col.get_normal()
		_respond(n, e, u, rules.bounce_min_speed)
		if n.y < FLOOR_NORMAL_Y:
			floor_hit = true
		motion = col.get_remainder().slide(n)
	if floor_hit:
		foot_contact = true
		return
	# Resting contact: a toy within a hair of the floor is standing on it.
	var probe := move_and_collide(Vector2(0.0, PROBE_DISTANCE), true, SAFE_MARGIN, true)
	if probe != null and probe.get_normal().y < FLOOR_NORMAL_Y:
		foot_contact = true
		var n := probe.get_normal()
		if velocity.dot(n) < 0.0:
			position += probe.get_travel()
			_respond(n, e, u, rules.bounce_min_speed)


func _respond(n: Vector2, e: float, u: float, bounce_min: float) -> void:
	var vn := velocity.dot(n)
	if vn >= 0.0:
		return
	var restitution := e if -vn > bounce_min else 0.0
	var tangent := velocity - n * vn
	var push := -(1.0 + restitution) * vn
	velocity += n * push
	var vt := tangent.length()
	if vt > 0.0:
		velocity -= tangent / vt * minf(vt, u * push)
