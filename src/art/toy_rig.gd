class_name ToyRig
extends RefCounted
## A cutout rig from the art lab's rig.json: parts with pivots, parents and draw order, solved
## by forward kinematics, with two-bone arm IK toward a weapon's grip and support points (the
## same maths as `art/tools/compose.py`, so the game and the art lab's previews agree).
##
## Everything here is in author px (8 per u), in the rig's own frame: the root is the ground
## point between the feet, facing right, y down, rotations in degrees clockwise.

class Part:
	var name: StringName
	var piece: StringName
	var pivot: Vector2
	var parent: int = -1
	var pos: Vector2
	var rot: float = 0.0
	var z: float = 0.0
	var modulate: Color = Color.WHITE


var parts: Array[Part] = []
var index: Dictionary = {}
## Parts in draw order.
var order: PackedInt32Array = []
var sockets: Dictionary = {}
var faces: Dictionary = {}
var team: Dictionary = {}
## Arm lengths for the IK: shoulder to elbow, elbow to fist, and the fist's angle off the
## forearm's axis.
var arm_upper: float = 0.0
var arm_fore: float = 0.0
var fist_angle: float = 0.0

static var _soldier: ToyRig


static func soldier() -> ToyRig:
	if _soldier == null:
		_soldier = ToyRig.from_data(ArtLibrary.rig(), ArtLibrary.SOLDIER)
	return _soldier


static func from_data(d: Dictionary, folder: String) -> ToyRig:
	var r := ToyRig.new()
	for p: Dictionary in d.get("parts", []):
		var part := Part.new()
		part.name = StringName(p.name)
		part.piece = StringName(folder + String(p.file).get_basename())
		part.pivot = _v(p.pivot)
		part.pos = _v(p.pos)
		part.rot = float(p.get("rot", 0.0))
		part.z = float(p.z)
		if p.has("modulate"):
			var m: Array = p.modulate
			part.modulate = Color(m[0], m[1], m[2], m[3])
		r.index[part.name] = r.parts.size()
		r.parts.append(part)
	for i in r.parts.size():
		var p: Dictionary = d.parts[i]
		r.parts[i].parent = r.index.get(StringName(p.parent), -1)
	var ids := range(r.parts.size())
	ids.sort_custom(func(a: int, b: int) -> bool: return r.parts[a].z < r.parts[b].z)
	r.order = PackedInt32Array(ids)
	r.sockets = d.get("sockets", {})
	for k: String in d.get("faces", {}):
		r.faces[StringName(k)] = StringName(folder + String(d.faces[k]).get_basename())
	r.team = d.get("team", {})
	if r.index.has(&"near_forearm") and r.sockets.has("weapon_grip"):
		var fist := _v(r.sockets.weapon_grip.pos)
		r.arm_upper = r.parts[r.index[&"near_forearm"]].pos.y
		r.arm_fore = fist.length()
		r.fist_angle = rad_to_deg(atan2(fist.x, fist.y))
	return r


static func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## World matrix of every part. `root` places the rig's root; `rots` overrides part rotations
## (degrees) by name; parts are solved parent first.
func solve(root: Transform2D, rots: Dictionary) -> Array[Transform2D]:
	var out: Array[Transform2D] = []
	out.resize(parts.size())
	var done := PackedByteArray()
	done.resize(parts.size())
	for i in parts.size():
		_solve(i, root, rots, out, done)
	return out


func _solve(i: int, root: Transform2D, rots: Dictionary, out: Array[Transform2D], done: PackedByteArray) -> Transform2D:
	if done[i]:
		return out[i]
	var p := parts[i]
	var parent_xf := root if p.parent < 0 else _solve(p.parent, root, rots, out, done)
	var rot: float = rots.get(p.name, p.rot)
	out[i] = parent_xf * Transform2D(deg_to_rad(rot), p.pos)
	done[i] = 1
	return out[i]


## The matrix that draws a part's image: its world matrix moved back by the pivot.
func image_xf(i: int, world: Transform2D) -> Transform2D:
	return world * Transform2D(0.0, -parts[i].pivot)


## A socket's point in the rig frame, from the solved matrices.
func socket_point(socket: Dictionary, solved: Array[Transform2D], root: Transform2D) -> Vector2:
	var parent: int = index.get(StringName(socket.get("parent", "root")), -1)
	var xf := root if parent < 0 else solved[parent]
	return xf * _v(socket.pos)


## Two-bone IK for a limb hanging along +y at rest, reaching `target` from `shoulder`, both in
## the parent's frame. Returns (upper, fore) rotations in degrees as the rig applies them.
static func two_bone(shoulder: Vector2, target: Vector2, l1: float, l2: float, bend: float = 1.0) -> Vector2:
	var d := target - shoulder
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var a := atan2(d.y, d.x)
	var alpha := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var beta := acos(clampf((l1 * l1 + l2 * l2 - dist * dist) / (2.0 * l1 * l2), -1.0, 1.0))
	var upper := rad_to_deg(a + bend * alpha) - 90.0
	var fore := -bend * (180.0 - rad_to_deg(beta))
	return Vector2(upper, fore)


## Sets the arm's two rotations in `rots` so its fist reaches `target` (rig frame). `side` is
## "near" or "far". `torso_xf` is the solved torso matrix.
func reach(side: String, target: Vector2, torso_xf: Transform2D, rots: Dictionary, bend: float = 1.0) -> void:
	var upper := StringName(side + "_upper_arm")
	var fore := StringName(side + "_forearm")
	if not index.has(upper) or not index.has(fore):
		return
	var shoulder := parts[index[upper]].pos
	var local := torso_xf.affine_inverse() * target
	var ang := two_bone(shoulder, local, arm_upper, arm_fore, bend)
	rots[upper] = ang.x
	rots[fore] = ang.y + fist_angle
