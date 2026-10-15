class_name ToyAnimator
extends RefCounted
## Turns a toy's sim state into a posed cutout rig each frame: idle, run, jump, fly, crouch,
## arms that follow the aim to the weapon's grip, recoil, a flinch on hit, the face, and the
## body lean of T-17 (US-03.4). Animation is code, from the art lab's key poses (poses.json).
##
## View only: reads `SimToy` and `Fighter`, never writes them. Output (`frame`) is in the toy
## node's local space in world units: origin at the body origin, y down.

## One frame of a posed toy, ready to draw.
class Frame:
	## [piece, Transform2D, Color] in draw order. The transform draws the piece's image
	## (author px, top-left at 0,0) in the node's space.
	var items: Array = []
	## Muzzle of the main weapon (and the off-hand one): origin at the muzzle, x along the barrel.
	var muzzles: Array[Transform2D] = []
	## Battery nozzle exits, and the direction the thrust leaves them (unit, y down).
	var nozzles: PackedVector2Array = []
	var thrust_dir: Vector2 = Vector2.DOWN
	## Joints, for the pop's snaps.
	var joints: PackedVector2Array = []
	var face: StringName = &"determined"
	## Rig matrices per part (node space), for the pop: parts fly off from where they were.
	var parts: Array[Transform2D] = []
	var lean: float = 0.0
	var facing: float = 1.0


const PX := 1.0 / ArtAtlas.AUTHOR_PX_PER_U
## Drawn lean limit, radians (T-17 gives the weights, this keeps a toy readable).
const MAX_LEAN := 0.35
const LEAN_RATE := 10.0
## Pose easing per second.
const POSE_RATE := 22.0
## World units per run cycle (two steps).
const STRIDE := 58.0
const RECOIL_DECAY := 16.0
const FLINCH_DECAY := 7.0
const HURT_FACE_TIME := 0.6
const COCKY_FACE_TIME := 1.6
## Where the arms aim from, and where the grip sits at rest, rig px (poses.json "aim").
const AIM_PIVOT := Vector2(6, -204)
const GRIP_REST := Vector2(62, -160)
## Off-hand gun sits a little forward and up of the main one, held by the far arm.
const OFF_GRIP := Vector2(46, -40)
## Handless toys float the gun here, beside the body (US-11.5).
const FLOAT_GRIP := Vector2(150, -170)
const HIP := Vector2(0, -152)

var rig: ToyRig
var rules: Ruleset
var poses: Dictionary
## No hands: the weapon floats beside the toy (US-11.5). The soldier has hands.
var handless: bool = false

var _rots: Dictionary = {}
var _offset: Vector2 = Vector2.ZERO
var _lean: float = 0.0
var _facing: float = 1.0
var _phase: float = 0.0
var _time: float = 0.0
var _recoil: float = 0.0
var _recoil_off: float = 0.0
var _flinch: float = 0.0
var _flinch_side: float = 1.0
var _hurt_left: float = 0.0
var _cocky_left: float = 0.0
var _aim_deg: float = 0.0


func _init(toy_rig: ToyRig = null, ruleset: Ruleset = null) -> void:
	rig = toy_rig if toy_rig != null else ToyRig.soldier()
	rules = ruleset
	poses = ArtLibrary.poses()


## A shot left this toy's gun: kick it back. `off_hand` kicks the other gun.
func kick(off_hand: bool = false) -> void:
	if off_hand:
		_recoil_off = 1.0
	else:
		_recoil = 1.0


## A hit landed on this toy from `from_x` (world x of the attacker).
func flinch(from_x: float, toy_x: float) -> void:
	_flinch = 1.0
	_flinch_side = signf(from_x - toy_x) * _facing if from_x != toy_x else 1.0
	_hurt_left = HURT_FACE_TIME


func scored() -> void:
	_cocky_left = COCKY_FACE_TIME


## Body lean the toy would show for this state (T-17), radians, clockwise positive.
static func lean_target(toy: SimToy, r: Ruleset) -> float:
	if toy.crouched or not toy.stick_held or toy.stick == Vector2.ZERO:
		return 0.0
	var w := r.lean_facing_flying if toy.mode() == SimToy.Mode.FLYING else r.lean_facing_ground
	var stick_world := Vector2(toy.stick.x, -toy.stick.y)
	var up := (Vector2.UP * w + stick_world * (1.0 - w)).normalized()
	return clampf(Vector2.UP.angle_to(up), -MAX_LEAN, MAX_LEAN)


func update(toy: SimToy, fighter: Fighter, velocity: Vector2, delta: float) -> Frame:
	_time += delta
	_recoil *= exp(-RECOIL_DECAY * delta)
	_recoil_off *= exp(-RECOIL_DECAY * delta)
	_flinch *= exp(-FLINCH_DECAY * delta)
	_hurt_left = maxf(0.0, _hurt_left - delta)
	_cocky_left = maxf(0.0, _cocky_left - delta)

	# Facing and aim: the fighter's aim when it has one, else the sim's facing.
	var aim := Vector2(toy.facing.x, -toy.facing.y)
	if fighter != null:
		aim = fighter.aim
	if absf(aim.x) > 0.05:
		_facing = signf(aim.x)
	var local_aim := Vector2(absf(aim.x), aim.y).normalized()
	_aim_deg = rad_to_deg(atan2(local_aim.y, local_aim.x))

	_lean = lerpf(_lean, lean_target(toy, rules), clampf(delta * LEAN_RATE, 0.0, 1.0))

	# Body pose by state.
	var mode := toy.mode()
	var target := {}
	var offset := Vector2.ZERO
	var on_ground := toy.foot_contact and mode != SimToy.Mode.FLYING
	match mode:
		SimToy.Mode.FLYING:
			target = _pose_rots("fly")
			offset = _pose_offset("fly")
			var trail := clampf(-velocity.x * _facing * 0.06, -16.0, 16.0)
			var wob := sin(_time * 7.0) * 4.0
			target[&"near_thigh"] += trail
			target[&"far_thigh"] += trail
			target[&"near_shin"] += wob
			target[&"far_shin"] -= wob
		SimToy.Mode.CROUCHED:
			target = {&"near_thigh": -78.0, &"near_shin": 108.0, &"far_thigh": -62.0, &"far_shin": 102.0, &"head": -2.0}
			offset = Vector2(4, 64)
		SimToy.Mode.AIRBORNE:
			var falling := clampf(velocity.y / 300.0, -1.0, 1.0)
			target = {&"near_thigh": -34.0 + 14.0 * falling, &"near_shin": 56.0 - 20.0 * falling,
				&"far_thigh": 16.0, &"far_shin": 44.0 - 16.0 * falling, &"head": -5.0}
			offset = Vector2(0, -8)
		_:
			var speed := absf(velocity.x)
			if on_ground and speed > 12.0:
				_phase = fmod(_phase + speed * delta / STRIDE * TAU, TAU)
				var amp := clampf(speed / 130.0, 0.35, 1.0)
				var s := sin(_phase)
				# The leg moving forward is the one the toy runs towards: run backwards
				# (aiming behind) swings the other way.
				var dir := signf(velocity.x) * _facing
				var near := -4.0 - 38.0 * amp * s * dir
				var far := -4.0 + 38.0 * amp * s * dir
				target = {&"near_thigh": near, &"far_thigh": far,
					&"near_shin": 14.0 + maxf(0.0, near) * 1.2 + 10.0 * amp,
					&"far_shin": 14.0 + maxf(0.0, far) * 1.2 + 10.0 * amp,
					&"head": -6.0}
				offset = Vector2(0, -6.0 - 8.0 * absf(cos(_phase)) * amp)
			else:
				target = _pose_rots("stand")
				offset = Vector2(0, sin(_time * 2.4) * 1.5)
				target[&"head"] = float(target.get(&"head", 0.0)) + sin(_time * 1.3) * 1.5

	# Flinch: the body snaps away from the hit.
	target[&"torso"] = float(target.get(&"torso", 0.0)) - 9.0 * _flinch * _flinch_side - 3.0 * _recoil
	target[&"head"] = float(target.get(&"head", 0.0)) - 14.0 * _flinch * _flinch_side - 4.0 * _recoil
	offset += Vector2(-12.0 * _flinch * _flinch_side, 0.0)

	var k := clampf(delta * POSE_RATE, 0.0, 1.0)
	for part in rig.parts:
		var want: float = target.get(part.name, part.rot)
		_rots[part.name] = lerpf(float(_rots.get(part.name, want)), want, k)
	_offset = _offset.lerp(offset, k)

	return _compose(toy, fighter, aim, mode)


func _pose_rots(pose_name: String) -> Dictionary:
	var out := {}
	var p: Dictionary = poses.get(pose_name, {})
	for n: String in p.get("rot", {}):
		out[StringName(n)] = float(p.rot[n])
	for n: StringName in [&"near_thigh", &"near_shin", &"far_thigh", &"far_shin", &"head"]:
		if not out.has(n):
			out[n] = 0.0
	return out


func _pose_offset(pose_name: String) -> Vector2:
	var o: Array = poses.get(pose_name, {}).get("offset", [0, 0])
	return Vector2(float(o[0]), float(o[1]))


func _compose(toy: SimToy, fighter: Fighter, aim_world: Vector2, mode: SimToy.Mode) -> Frame:
	var f := Frame.new()
	f.facing = _facing
	f.lean = _lean
	var feet := -rules.body_bottom
	# Node space <- rig space: feet on the ground point, mirrored to face, author px to u.
	var base := Transform2D(0.0, Vector2(_facing * PX, PX), 0.0, Vector2(0.0, feet)) * Transform2D(0.0, _offset)
	# Lean about the feet on the ground, about the hips in the air.
	var pivot := HIP if mode == SimToy.Mode.FLYING or mode == SimToy.Mode.AIRBORNE else Vector2.ZERO
	var lean_deg := rad_to_deg(_lean) * _facing
	var root := base * Transform2D(0.0, pivot) * Transform2D(deg_to_rad(lean_deg), Vector2.ZERO) * Transform2D(0.0, -pivot)

	var rots := _rots.duplicate()
	var solved := rig.solve(root, rots)
	var torso_xf: Transform2D = solved[rig.index[&"torso"]]

	# Weapons and arms.
	var main: WeaponItem = fighter.main_weapon() if fighter != null else null
	var off: WeaponItem = fighter.off_weapon() if fighter != null else null
	var weapons: Array = []
	# The gun's angle in rig space is the aim, whatever the lean.
	var gun_deg := _aim_deg - lean_deg
	var aim_rad := deg_to_rad(_aim_deg)
	var crouch_drop := Vector2(0, 30) if mode == SimToy.Mode.CROUCHED else Vector2.ZERO
	if main != null:
		var w := ArtLibrary.weapon(main.id())
		if not w.is_empty():
			var grip := _grip_point(GRIP_REST, aim_rad, _recoil) + crouch_drop
			if handless:
				grip = FLOAT_GRIP + Vector2(0, sin(_time * 3.0) * 6.0)
			var wxf := root * Transform2D(deg_to_rad(gun_deg - 9.0 * _recoil), grip)
			weapons.append([main.id(), w, wxf, 14.0])
			if not handless:
				rig.reach("near", wxf.origin, torso_xf, rots)
				if off == null and w.has("support") and int(w.get("hands", 1)) >= 2:
					var sup := wxf * (ArtLibrary.weapon_support(w) - ArtLibrary.weapon_grip(w))
					rig.reach("far", sup, torso_xf, rots)
	if off != null:
		var w2 := ArtLibrary.weapon(off.id())
		if not w2.is_empty():
			var grip2 := _grip_point(GRIP_REST + OFF_GRIP, aim_rad, _recoil_off) + crouch_drop
			if handless:
				grip2 = FLOAT_GRIP + Vector2(-40, -60) + Vector2(0, cos(_time * 3.0) * 6.0)
			var wxf2 := root * Transform2D(deg_to_rad(gun_deg - 9.0 * _recoil_off), grip2)
			weapons.append([off.id(), w2, wxf2, 1.5])
			if not handless:
				rig.reach("far", wxf2.origin, torso_xf, rots)
	if main == null and not handless:
		# Bare hands: fists up along the aim, ready to swing.
		var fist := _grip_point(Vector2(52, -176), aim_rad, 0.0)
		rig.reach("near", root * fist, torso_xf, rots)
	solved = rig.solve(root, rots)

	# Draw list, by z; weapons go in at their slot.
	var face_piece: StringName = rig.faces.get(_face(toy, fighter, mode), rig.faces.get(&"determined", &""))
	f.face = _face(toy, fighter, mode)
	var team_info := {}
	for i in rig.order:
		var part := rig.parts[i]
		for wpn: Array in weapons:
			if wpn[3] <= part.z and not wpn.has(&"drawn"):
				_add_weapon(f, wpn)
				wpn.append(&"drawn")
		var piece := part.piece
		if part.name == &"face":
			piece = face_piece
		f.items.append([piece, rig.image_xf(i, solved[i]), part.modulate, part.name])
	for wpn: Array in weapons:
		if not wpn.has(&"drawn"):
			_add_weapon(f, wpn)
	f.parts = solved

	# Nozzles and the way the thrust pushes: away from the stick (US-03.1).
	for s: Dictionary in rig.sockets.get("thrust", []):
		f.nozzles.append(rig.socket_point(s, solved, root))
	var push := Vector2(toy.stick.x, -toy.stick.y)
	f.thrust_dir = -push.normalized() if toy.stick_held and push.length() > 0.1 else Vector2.DOWN
	for n: StringName in [&"near_forearm", &"far_forearm", &"near_shin", &"far_shin", &"head", &"near_upper_arm", &"far_upper_arm", &"near_thigh", &"far_thigh"]:
		if rig.index.has(n):
			f.joints.append(solved[rig.index[n]].origin)
	return f


func _add_weapon(f: Frame, wpn: Array) -> void:
	var w: Dictionary = wpn[1]
	var wxf: Transform2D = wpn[2]
	var grip := ArtLibrary.weapon_grip(w)
	f.items.append([ArtLibrary.weapon_piece(wpn[0]), wxf * Transform2D(0.0, -grip), Color.WHITE, &"weapon"])
	var muzzle := ArtLibrary.weapon_muzzle(w) - grip
	var m := wxf * Transform2D(0.0, muzzle)
	# Keep the muzzle frame unscaled and pointing along the barrel, facing included.
	var x_axis := m.x.normalized()
	f.muzzles.append(Transform2D(x_axis, Vector2(-x_axis.y, x_axis.x), m.origin))


## The grip point for an aim: the rest grip swung about the chest, pulled back by recoil.
func _grip_point(rest: Vector2, aim_rad: float, recoil: float) -> Vector2:
	var p := AIM_PIVOT + (rest - AIM_PIVOT).rotated(aim_rad)
	return p - Vector2.from_angle(aim_rad) * 22.0 * recoil


func _face(toy: SimToy, fighter: Fighter, mode: SimToy.Mode) -> StringName:
	if _hurt_left > 0.0:
		return &"hurt"
	if fighter != null and rules != null and toy.health < rules.max_health * 0.25:
		return &"shocked"
	if toy.jetpack_on and toy.battery <= 0.0 and not toy.foot_contact:
		return &"shocked"
	if _cocky_left > 0.0 or (mode == SimToy.Mode.FLYING and toy.thrust > 0.0):
		return &"cocky"
	return &"determined"
