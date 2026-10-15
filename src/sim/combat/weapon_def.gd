class_name WeaponDef
extends RefCounted
## One row of the weapon table (T-50): everything a weapon does, as data (US-11.3).
## Built only by `WeaponTable`, which checks every field. `kind` names the behaviour; the
## numbers tune it. See `data/rulesets/standard/weapons.cfg` for what each field means.

const BULLET := &"bullet"
const ROCKET := &"rocket"
const MELEE := &"melee"

var id: StringName = &""
var display_name: String = ""
var kind: StringName = BULLET
var damage: float
var pellets: int
var spread: float
var interval: float
var burst: int
var burst_gap: float
var spin_up: float
var mag: int
var start_reserve: int
var max_reserve: int
var reload: float
var range: float
var bullet_speed: float
var zoom: PackedInt32Array = []
var weight: float
var melee_damage: float
var melee_reach: float
var dual: bool


func shoots() -> bool:
	return kind != MELEE


func to_dict() -> Dictionary:
	var out := {"id": String(id), "name": display_name, "kind": String(kind), "zoom": Array(zoom)}
	for f: Dictionary in WeaponTable.FIELDS:
		out[f.key] = get(f.key)
	return out
