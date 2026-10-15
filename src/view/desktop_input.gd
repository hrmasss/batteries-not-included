class_name DesktopInput
extends InputSource
## Keyboard and mouse, or a gamepad's twin sticks, as the move and aim sticks.


func intent_for(view: GameView, _tick: int) -> InputIntent:
	var i := InputIntent.new()
	i.move = Input.get_vector(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.MOVE_DOWN, InputActions.MOVE_UP)
	i.move_held = i.move != Vector2.ZERO
	var pad_aim := Input.get_vector(InputActions.AIM_LEFT, InputActions.AIM_RIGHT, InputActions.AIM_DOWN, InputActions.AIM_UP)
	if pad_aim != Vector2.ZERO:
		i.aim = pad_aim.normalized()
	elif view.player != null:
		var to_mouse := view.get_global_mouse_position() - view.player_view_position()
		if to_mouse.length() > 1.0:
			i.aim = Vector2(to_mouse.x, -to_mouse.y).normalized()
	i.fire = Input.is_action_pressed(InputActions.FIRE)
	for b: Array in InputActions.BUTTONS:
		i.set_button(b[1], Input.is_action_pressed(b[0]))
	return i
