class_name ArtLibrary
extends RefCounted
## The art lab's metadata (rig.json, poses.json, weapons.json, fx.json, kit.json) and the sheets
## built from its SVGs. Pieces are named by their path under `assets/` without `.svg`, for
## example `toys/soldier/head` or `fx/tracer`.

const ASSETS := "res://assets/"
const SOLDIER := "toys/soldier/"
## Our weapon art by the weapon table's id (T-50), where the two differ.
const WEAPON_ART := {&"pump_shotgun": &"shotgun"}
## Pattern overlay per team, on the batteries' wraps (US-26.2): teams differ by shape too.
const TEAM_PATTERNS: PackedStringArray = ["", "stripes", "dots", "chevrons"]

static var _json: Dictionary = {}


static func data(path: String) -> Dictionary:
	if not _json.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + path))
		_json[path] = parsed if parsed is Dictionary else {}
	return _json[path]


static func rig() -> Dictionary:
	return data(SOLDIER + "rig.json")


static func poses() -> Dictionary:
	return data(SOLDIER + "poses.json")


static func weapons() -> Dictionary:
	return data("weapons/weapons.json").get("weapons", {})


static func fx() -> Dictionary:
	return data("fx/fx.json").get("fx", {})


static func pickups() -> Dictionary:
	return data("pickups/pickups.json").get("pickups", {})


static func kit() -> Dictionary:
	return data("maps/bedroom/kit.json").get("pieces", {})


## Weapon art entry for a weapon id, or empty.
static func weapon(id: StringName) -> Dictionary:
	return weapons().get(String(WEAPON_ART.get(id, id)), {})


static func weapon_piece(id: StringName) -> StringName:
	var w := weapon(id)
	return StringName("weapons/" + String(w.file).get_basename()) if not w.is_empty() else &""


static func fx_piece(name: String) -> StringName:
	return StringName("fx/" + name)


## Every SVG the soldier rig names: parts, faces, baked team layers, team patterns.
static func soldier_files() -> PackedStringArray:
	var r := rig()
	var out := PackedStringArray()
	for p: Dictionary in r.get("parts", []):
		if not out.has(p.file):
			out.append(p.file)
	for f: String in r.get("faces", {}).values():
		if not out.has(f):
			out.append(f)
	var team: Dictionary = r.get("team", {})
	for f: String in team.get("baked", {}).values():
		out.append(f)
	for f: String in team.get("pattern_files", {}).values():
		out.append(f)
	return out


## Toys, weapons and effects: one sheet, so a fight draws from one texture.
static func actors() -> ArtAtlas:
	var files := {}
	for f in soldier_files():
		files[StringName(SOLDIER + f.get_basename())] = ASSETS + SOLDIER + f
	for id: String in weapons():
		files[StringName("weapons/" + String(weapons()[id].file).get_basename())] = ASSETS + "weapons/" + weapons()[id].file
	for id: String in fx():
		files[fx_piece(id)] = ASSETS + "fx/" + fx()[id].file
	for id: String in pickups():
		files[StringName("pickups/" + id)] = ASSETS + "pickups/" + pickups()[id].file
	return ArtAtlas.sheet("actors", files)


## The bedroom's playable pieces (props, tiles) at full density, and its backdrop and light
## pieces at a lower one: muted art that is meant to read soft.
static func bedroom(backdrop: bool) -> ArtAtlas:
	var files := {}
	var k := kit()
	for id: String in k:
		var is_back: bool = k[id].kind == "backdrop" or k[id].kind == "light"
		if is_back == backdrop:
			files[StringName(id)] = ASSETS + "maps/bedroom/" + k[id].file
	return ArtAtlas.sheet("bedroom_back" if backdrop else "bedroom", files, 0.75 if backdrop else 1.0)


## A weapon's points, author px from the file's top-left.
static func weapon_grip(w: Dictionary) -> Vector2:
	return _point(w, "grip")


static func weapon_muzzle(w: Dictionary) -> Vector2:
	return _point(w, "muzzle")


static func weapon_support(w: Dictionary) -> Vector2:
	return _point(w, "support") if w.has("support") else _point(w, "grip")


static func _point(d: Dictionary, k: String) -> Vector2:
	var a: Array = d.get(k, [0, 0])
	return Vector2(float(a[0]), float(a[1]))
