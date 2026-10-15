extends Node2D
## A muted backdrop for the demo room: a pale wall with soft stripes and a window, so the playable
## terrain reads against it (docs/art "Maps"). Placeholder until the art task's bedroom lands.

var room: Rect2 = Rect2()


func _ready() -> void:
	z_index = -10
	queue_redraw()


func _draw() -> void:
	draw_rect(room.grow(400), Color("cfc4b4"))
	var x := room.position.x
	var i := 0
	while x < room.end.x:
		draw_rect(Rect2(x, room.position.y, 80, room.size.y), Color("c6baa8") if i % 2 == 0 else Color("cfc4b4"))
		x += 80.0
		i += 1
	draw_rect(Rect2(room.position.x, room.end.y - 120, room.size.x, 120), Color("b7a993"))
	var win := Rect2(1400, -200, 520, 420)
	draw_rect(win.grow(18), Color("a89377"))
	draw_rect(win, Color("9fb8cc"))
	draw_line(win.get_center() - Vector2(0, win.size.y * 0.5), win.get_center() + Vector2(0, win.size.y * 0.5), Color("a89377"), 14)
	draw_line(win.get_center() - Vector2(win.size.x * 0.5, 0), win.get_center() + Vector2(win.size.x * 0.5, 0), Color("a89377"), 14)
