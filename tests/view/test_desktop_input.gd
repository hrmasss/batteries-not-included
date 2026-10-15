extends GutTest
## Desktop devices produce the one input intent: WASD as the move stick, buttons as the mask.

var _view: GameView


func before_each() -> void:
	InputActions.ensure()
	_view = GameView.new()


func after_each() -> void:
	for a in [InputActions.MOVE_RIGHT, InputActions.MOVE_UP, InputActions.MOVE_DOWN, &"reload", InputActions.FIRE]:
		Input.action_release(a)
	_view.free()


func test_keys_make_a_stick() -> void:
	var src := DesktopInput.new()
	autofree(src)
	assert_false(src.intent_for(_view, 0).move_held, "no key, thumb off the stick")
	Input.action_press(InputActions.MOVE_RIGHT)
	Input.action_press(InputActions.MOVE_UP)
	var i := src.intent_for(_view, 0)
	assert_true(i.move_held)
	assert_almost_eq(i.move.x, sqrt(0.5), 0.001, "diagonal is a full-length stick")
	assert_almost_eq(i.move.y, sqrt(0.5), 0.001, "up is positive")


func test_down_crouches_and_buttons_map() -> void:
	var src := DesktopInput.new()
	autofree(src)
	Input.action_press(InputActions.MOVE_DOWN)
	Input.action_press(&"reload")
	Input.action_press(InputActions.FIRE)
	var i := src.intent_for(_view, 0)
	assert_eq(i.move, Vector2(0, -1))
	assert_true(i.is_down(InputIntent.Act.RELOAD))
	assert_false(i.is_down(InputIntent.Act.GRENADE))
	assert_true(i.fire)
