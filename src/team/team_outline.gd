class_name TeamOutline
extends CanvasGroup
## The team hooks for a toy's drawing (US-26.1, US-26.4). The art task's toy rig goes under this
## node; it draws a thin team outline around the whole toy, and hands the team colour to any
## child part named in `battery_parts` or `wire_parts` (the two AA batteries and their wires).
##
## Parts take the colour through `modulate`, so the art can ship them greyscale. A part that
## wants its own handling can define `set_team_color(color: Color)` instead.

const SHADER := preload("res://src/team/team_outline.gdshader")

## Outline width in screen pixels.
@export var width: float = 2.0
## Node names (anywhere below) that are batteries and wires.
@export var battery_parts: PackedStringArray = ["Battery", "BatteryA", "BatteryB", "Batteries"]
@export var wire_parts: PackedStringArray = ["Wire", "WireA", "WireB", "Wires"]

var team: int = -2


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	fit_margin = width + 2.0
	if team == -2:
		set_team(-1)


## -1 is free-for-all.
func set_team(t: int) -> void:
	team = t
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("outline_color", TeamPalette.outline_color(t))
		mat.set_shader_parameter("width", width)
	_tint(self)


func _tint(n: Node) -> void:
	for c in n.get_children():
		var tint := Color(-1, 0, 0)
		if battery_parts.has(c.name):
			tint = TeamPalette.battery_color(team)
		elif wire_parts.has(c.name):
			tint = TeamPalette.wire_color(team)
		if tint.r >= 0.0:
			if c.has_method("set_team_color"):
				c.call("set_team_color", tint)
			elif c is CanvasItem:
				(c as CanvasItem).modulate = tint
		_tint(c)
