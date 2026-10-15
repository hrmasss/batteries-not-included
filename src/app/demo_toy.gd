class_name DemoToy
extends Node2D
## A placeholder toy drawing for the controls and HUD demo, until the art task's rig lands. It
## shows the team hooks working: it sits under a `TeamOutline`, and its two batteries and wires
## are separate white parts that the outline tints with the team colour.

var toy: SimToy
var _batteries: Array[Polygon2D] = []
var _wires: Array[Line2D] = []


func _ready() -> void:
	for i in 2:
		var b := Polygon2D.new()
		b.name = "BatteryA" if i == 0 else "BatteryB"
		var x := -17.5 - i * 6.0
		b.polygon = PackedVector2Array([Vector2(x, -4), Vector2(x + 5.5, -4), Vector2(x + 5.5, 12), Vector2(x, 12)])
		b.color = Color.WHITE
		add_child(b)
		_batteries.append(b)
		var w := Line2D.new()
		w.name = "WireA" if i == 0 else "WireB"
		w.width = 1.6
		w.default_color = Color.WHITE
		w.points = PackedVector2Array([Vector2(x + 2.75, -4), Vector2(x + 5.0, -9), Vector2(-6.0, -6)])
		add_child(w)
		_wires.append(w)


func _process(_dt: float) -> void:
	if toy == null:
		return
	var face := toy.facing.x < 0.0
	scale.x = -1.0 if face else 1.0
	queue_redraw()


func _draw() -> void:
	if toy == null:
		return
	# Drawn on the shared hitbox (T-18): body box from 5 above the origin to the feet 15 below,
	# head circle 14 above; crouched, the head is off and a low box sits on top.
	var ink := Color("2b2233")
	var body := Color("6b8f3a")
	var crouch := toy.crouched
	draw_rect(Rect2(-10, 6, 8, 9).grow(1.2), ink)
	draw_rect(Rect2(-10, 6, 8, 9), body.darkened(0.25))
	draw_rect(Rect2(2, 6, 8, 9).grow(1.2), ink)
	draw_rect(Rect2(2, 6, 8, 9), body.darkened(0.25))
	draw_rect(Rect2(-12, -5, 24, 12).grow(1.5), ink)
	draw_rect(Rect2(-12, -5, 24, 12), body)
	var head := Vector2(0, -6) if crouch else Vector2(0, -14)
	draw_circle(head, 12.0, ink)
	draw_circle(head, 10.5, Color("f1c27d"))
	draw_circle(head + Vector2(4.5, -1.5), 1.7, ink)
	draw_arc(head + Vector2(0, -1), 10.5, PI, TAU, 14, body.darkened(0.1), 6.0)
	# The gun along the aim.
	var aim := Vector2(absf(toy.facing.x), -toy.facing.y).normalized()
	var hand := Vector2(6, 1)
	draw_line(hand, hand + aim * 22.0, ink, 7.0)
	draw_line(hand, hand + aim * 22.0, Color("ff8c1a"), 4.0)
	# Thrust flames from the battery nozzles, pushing down.
	if toy.thrust > 0.0:
		for x in [-14.75, -20.75]:
			var l: float = 8.0 + 16.0 * toy.thrust
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 12), Vector2(x + 3, 12), Vector2(x, 12 + l)]), Color(1.0, 0.7, 0.2, 0.9))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 1.5, 12), Vector2(x + 1.5, 12), Vector2(x, 12 + l * 0.6)]), Color(1, 1, 0.8, 0.95))
