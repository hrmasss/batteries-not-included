class_name MenuBackdrop
extends Node2D
## The art bedroom behind the menus: the default map drawn, the camera drifting slowly along
## the room. Only for looks; a match frees it first, since two maps in one physics space would
## touch each other's toys.

## Drift speed, u/s, and how far up the room the camera looks, share of the height from the floor.
const DRIFT := 18.0
const LOOK_UP := 0.3
const ZOOM := 0.9

var map: GameMap
var camera := Camera2D.new()
var _dir: float = 1.0


func _ready() -> void:
	name = "MenuBackdrop"
	map = (load(MatchConfig.DEFAULT_MAP) as PackedScene).instantiate()
	# Looks only: no collision in the world while a menu shows.
	for t: Node in map.find_children("*", "Terrain", true, false):
		t.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(map)
	camera.zoom = Vector2(ZOOM, ZOOM)
	var b := map.bounds
	camera.limit_left = int(b.position.x)
	camera.limit_top = int(b.position.y)
	camera.limit_right = int(b.end.x)
	camera.limit_bottom = int(b.end.y)
	camera.position = Vector2(b.position.x + b.size.x * 0.25, b.end.y - b.size.y * LOOK_UP)
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	var b := map.bounds
	var half := get_viewport_rect().size.x * 0.5 / ZOOM
	camera.position.x += _dir * DRIFT * delta
	if camera.position.x > b.end.x - half:
		_dir = -1.0
	elif camera.position.x < b.position.x + half:
		_dir = 1.0
