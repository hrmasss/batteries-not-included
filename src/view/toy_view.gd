class_name ToyView
extends Node2D
## Draws one toy from its sim state, between the last two ticks. Placeholder shapes until the
## art task's toy lands: body and head from the shared hitbox, two AA batteries on the back,
## flames from the nozzles while thrusting, an aim line.
##
## Reads `SimToy` and the ruleset; changes neither.

const OLIVE := Color(0.42, 0.48, 0.23)
const OLIVE_DARK := Color(0.27, 0.31, 0.14)
const OUTLINE := Color(0.08, 0.08, 0.06)
const BATTERY := Color(0.12, 0.12, 0.13)
const BATTERY_TOP := Color(0.78, 0.46, 0.2)
const FLAME := Color(1.0, 0.62, 0.15)
const FLAME_CORE := Color(1.0, 0.93, 0.6)
const HITBOX := Color(1.0, 0.1, 0.3)
const HITBOX_HEAD := Color(1.0, 0.85, 0.1)
## Largest drawn lean, radians.
const MAX_LEAN := 0.35
const LEAN_SPEED := 10.0

var toy: SimToy
var rules: Ruleset
var show_hitboxes: bool = false
var show_battery: bool = true

var _lean: float = 0.0
var _flicker: float = 0.0


func _init(sim_toy: SimToy = null, ruleset: Ruleset = null) -> void:
	toy = sim_toy
	rules = ruleset
	z_index = 10


func sync(alpha: float, delta: float) -> void:
	position = toy.prev_position.lerp(toy.position, alpha)
	# T-17: the body leans between its facing (upright) and the stick.
	var facing_weight := rules.lean_facing_flying if toy.mode() == SimToy.Mode.FLYING else rules.lean_facing_ground
	var target := 0.0
	if toy.stick_held and toy.stick != Vector2.ZERO:
		var stick_world := Vector2(toy.stick.x, -toy.stick.y)
		var up := (Vector2.UP * facing_weight + stick_world * (1.0 - facing_weight)).normalized()
		target = clampf(Vector2.UP.angle_to(up), -MAX_LEAN, MAX_LEAN)
	if toy.crouched:
		target = 0.0
	_lean = lerpf(_lean, target, clampf(delta * LEAN_SPEED, 0.0, 1.0))
	_flicker += delta * 30.0
	queue_redraw()


func _draw() -> void:
	if toy == null:
		return
	var side := 1.0 if toy.facing.x >= 0.0 else -1.0
	var feet := -rules.body_bottom
	# Crouched: the standing figure squashed onto the feet, as tall as the crouch hitbox.
	var squash := 1.0
	if toy.crouched:
		squash = (rules.crouch_top - rules.body_bottom) / (rules.head_height + rules.head_radius - rules.body_bottom)
	draw_set_transform(Vector2(0.0, feet * (1.0 - squash)), _lean, Vector2(1.0, squash))
	_draw_flames(side, feet)
	_draw_batteries(side)
	_draw_body(side, feet)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_aim()
	if show_hitboxes:
		_draw_hitboxes()
	if show_battery:
		_draw_battery_bar(feet)


func _draw_body(side: float, feet: float) -> void:
	var top := -rules.body_top
	var w := rules.body_width
	# Legs.
	var leg_top := feet - 8.0
	draw_rect(Rect2(-w * 0.35, leg_top, w * 0.28, feet - leg_top), OLIVE_DARK)
	draw_rect(Rect2(w * 0.07, leg_top, w * 0.28, feet - leg_top), OLIVE_DARK)
	# Torso.
	var torso_top := top
	var torso := Rect2(-w * 0.5, torso_top, w, leg_top - torso_top)
	draw_rect(torso, OLIVE)
	draw_rect(torso, OUTLINE, false, 1.5)
	# Head and helmet.
	var head := Vector2(0.0, -rules.head_height)
	var r := rules.head_radius * 0.9
	draw_circle(head, r, OLIVE)
	draw_arc(head, r, 0.0, TAU, 24, OUTLINE, 1.5)
	draw_arc(head, r + 1.5, PI, TAU, 16, OLIVE_DARK, 3.0)
	draw_circle(head + Vector2(side * r * 0.45, -1.0), 1.6, OUTLINE)


func _draw_batteries(side: float) -> void:
	# Two AA batteries on the back, nozzles at the bottom.
	for k in 2:
		var x := -side * (rules.body_width * 0.5 + 2.0 + k * 6.0) - 3.0
		var body := Rect2(x, -rules.body_top - 2.0, 6.0, 15.0)
		draw_rect(body, BATTERY)
		draw_rect(Rect2(x, body.position.y - 3.0, 6.0, 3.0), BATTERY_TOP)
		draw_rect(Rect2(x - 0.5, body.position.y - 3.0, 7.0, 18.0), OUTLINE, false, 1.0)


func _draw_flames(side: float, _feet: float) -> void:
	if toy.thrust <= 0.0:
		return
	# Flames push against the direction of travel (US-03.1): away from the stick.
	var push := Vector2(toy.stick.x, -toy.stick.y)
	var dir := -push.normalized() if push.length() > 0.1 else Vector2.DOWN
	dir = dir.rotated(-_lean)
	var length := (10.0 + 24.0 * toy.thrust) * (0.85 + 0.15 * sin(_flicker))
	for k in 2:
		var x := -side * (rules.body_width * 0.5 + 2.0 + k * 6.0)
		var nozzle := Vector2(x, -rules.body_top + 13.0)
		var normal := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([nozzle + normal * 3.5, nozzle - normal * 3.5, nozzle + dir * length]), FLAME)
		draw_colored_polygon(PackedVector2Array([nozzle + normal * 1.8, nozzle - normal * 1.8, nozzle + dir * length * 0.55]), FLAME_CORE)


func _draw_aim() -> void:
	var aim := Vector2(toy.facing.x, -toy.facing.y)
	var shoulder := Vector2(0.0, -rules.body_top + 2.0)
	if toy.crouched:
		shoulder.y = -rules.crouch_top + 3.0
	draw_line(shoulder, shoulder + aim * 18.0, OUTLINE, 3.0)


func _draw_hitboxes() -> void:
	for cs: CollisionShape2D in toy.hit_shapes():
		var color := HITBOX_HEAD if cs.shape is CircleShape2D else HITBOX
		if cs.shape is CircleShape2D:
			draw_arc(cs.position, (cs.shape as CircleShape2D).radius, 0.0, TAU, 32, color, 1.0)
		else:
			var r := cs.shape.get_rect()
			r.position += cs.position
			draw_rect(r, color, false, 1.0)
	draw_circle(Vector2.ZERO, 1.5, HITBOX)


func _draw_battery_bar(feet: float) -> void:
	if toy.battery_max <= 0.0:
		return
	var share := clampf(toy.battery / toy.battery_max, 0.0, 1.0)
	var bar := Rect2(-14.0, feet + 5.0, 28.0, 3.0)
	draw_rect(bar.grow(1.0), OUTLINE)
	var color := Color(0.3, 0.85, 0.35).lerp(Color(0.95, 0.25, 0.2), 1.0 - share)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), color)
