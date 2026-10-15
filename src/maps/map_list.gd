class_name MapList
extends RefCounted
## The maps a host can pick: every `maps/<name>/<name>.tscn`. Maps are data (01_world "Maps"),
## so a new folder is a new map.

const DIR := "res://maps"


## [{path, name}] sorted by name.
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for folder in ResourceLoader.list_directory(DIR):
		if not folder.ends_with("/"):
			continue
		var id := folder.trim_suffix("/")
		var path := DIR.path_join(id).path_join("%s.tscn" % id)
		if not ResourceLoader.exists(path):
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var node := scene.instantiate()
		var map_name := id.capitalize()
		if node is GameMap and (node as GameMap).display_name != "":
			map_name = (node as GameMap).display_name
		node.free()
		out.append({"path": path, "name": map_name})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name < b.name)
	return out
