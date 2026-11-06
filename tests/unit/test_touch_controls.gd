extends GutTest

var tc: TouchControls

func before_each() -> void:
	tc = TouchControls.new()
	add_child_autofree(tc)
	tc.size = Vector2(1280, 720)
	tc.visible = true

func after_each() -> void:
	InputHub.consume_look(0.0)

func _touch(i: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = pressed
	tc._input(e)

func _drag(i: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	e.relative = rel
	tc._input(e)

func test_jump_button_presses_jump_action_until_released() -> void:
	var jump := tc.button_rect_center(0)
	_touch(3, jump, true)
	assert_true(Input.is_action_pressed("jump"))
	_touch(3, jump, false)
	assert_false(Input.is_action_pressed("jump"))

func test_left_side_drag_moves_forward() -> void:
	_touch(0, Vector2(200, 500), true)
	_drag(0, Vector2(200, 300), Vector2(0, -200))
	assert_gt(InputHub.move_vector().y, 0.9)
	_touch(0, Vector2(200, 300), false)
	assert_eq(InputHub.move_vector(), Vector2.ZERO)

func test_right_side_drag_rotates_camera() -> void:
	_touch(1, Vector2(900, 300), true)
	_drag(1, Vector2(940, 300), Vector2(40, 0))
	assert_eq(InputHub.consume_look(0.0), Vector2(40, 0))

func test_stick_button_and_camera_work_at_same_time() -> void:
	_touch(0, Vector2(200, 500), true)
	_drag(0, Vector2(330, 500), Vector2(130, 0))
	_touch(1, tc.button_rect_center(0), true)
	_touch(2, Vector2(800, 200), true)
	_drag(2, Vector2(800, 230), Vector2(0, 30))
	assert_gt(InputHub.move_vector().x, 0.9)
	assert_true(Input.is_action_pressed("jump"))
	assert_eq(InputHub.consume_look(0.0), Vector2(0, 30))
	_touch(1, tc.button_rect_center(0), false)
	_touch(0, Vector2(330, 500), false)

func test_hiding_releases_everything() -> void:
	_touch(1, tc.button_rect_center(0), true)
	tc.visible = false
	assert_false(Input.is_action_pressed("jump"))
