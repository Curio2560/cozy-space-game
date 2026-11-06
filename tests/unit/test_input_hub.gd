extends GutTest

func after_each() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	InputHub.consume_look(0.0)

func test_all_game_actions_exist_with_keyboard_binding() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back", "jump", "action", "vehicle", "debug_toggle"]:
		assert_true(InputMap.has_action(a), a)
		var has_key := InputMap.action_get_events(a).any(func(e: InputEvent) -> bool: return e is InputEventKey)
		assert_true(has_key, "%s sem tecla" % a)

func test_move_vector_forward_is_positive_y() -> void:
	Input.action_press("move_forward", 1.0)
	assert_almost_eq(InputHub.move_vector().y, 1.0, 0.01)

func test_move_vector_never_exceeds_one() -> void:
	Input.action_press("move_forward", 1.0)
	Input.action_press("move_right", 1.0)
	assert_almost_eq(InputHub.move_vector().length(), 1.0, 0.01)

func test_look_accumulates_and_is_consumed_once() -> void:
	InputHub.add_look(Vector2(10, 0))
	InputHub.add_look(Vector2(5, 2))
	assert_eq(InputHub.consume_look(0.0), Vector2(15, 2))
	assert_eq(InputHub.consume_look(0.0), Vector2.ZERO)
