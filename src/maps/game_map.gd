@tool
class_name GameMap
extends Node2D
## A map: solid terrain, backdrop, spawn points, pickup points, team bases, bounds and
## properties (01_world "Maps"). The format is written down in `docs/map-format.md`.
##
## Child layout, by node name:
##   Backdrop  any Node2D, drawn behind, no collision
##   Terrain   `Terrain` nodes (StaticBody2D) with collision shapes; what toys stand on
##   Spawns    `SpawnPoint` markers
##   Pickups   `PickupPoint` markers
##   Bases     `TeamBase` markers

## Shown in menus.
@export var display_name: String = ""
## Battery full on this map (T-20); -1 keeps the ruleset's.
@export var battery_full: float = -1.0
## Gravity factor for loose items (grenades, dropped guns); never for toys.
@export var item_gravity: float = 1.0
## Leaving this box hurts (T-34). World units, y down.
@export var bounds: Rect2 = Rect2(0, 0, 2048, 1024)


func spawn_points() -> Array[SpawnPoint]:
	var out: Array[SpawnPoint] = []
	var holder := get_node_or_null(^"Spawns")
	if holder:
		for c in holder.get_children():
			if c is SpawnPoint:
				out.append(c)
	return out


func pickup_points() -> Array[PickupPoint]:
	var out: Array[PickupPoint] = []
	var holder := get_node_or_null(^"Pickups")
	if holder:
		for c in holder.get_children():
			if c is PickupPoint:
				out.append(c)
	return out


func team_bases() -> Array[TeamBase]:
	var out: Array[TeamBase] = []
	var holder := get_node_or_null(^"Bases")
	if holder:
		for c in holder.get_children():
			if c is TeamBase:
				out.append(c)
	return out


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(bounds, Color(1, 0.3, 0.3, 0.8), false, 2.0)
