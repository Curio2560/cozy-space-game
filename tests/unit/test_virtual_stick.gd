extends GutTest

func test_idle_stick_gives_zero() -> void:
	assert_eq(VirtualStick.new(100.0).value(), Vector2.ZERO)

func test_inside_deadzone_gives_zero() -> void:
	var s := VirtualStick.new(100.0, 0.2)
	s.press(Vector2(500, 500))
	s.drag(Vector2(510, 500))
	assert_eq(s.value(), Vector2.ZERO)

func test_full_push_gives_unit_vector_in_direction() -> void:
	var s := VirtualStick.new(100.0, 0.1)
	s.press(Vector2(200, 200))
	s.drag(Vector2(200, 50)) # muito para cima, além do raio
	assert_almost_eq(s.value().length(), 1.0, 0.001)
	assert_almost_eq(s.value().y, -1.0, 0.001)
	assert_almost_eq(s.knob.distance_to(s.center), 100.0, 0.001, "o botão do stick fica no raio")

func test_half_push_is_between_zero_and_one() -> void:
	var s := VirtualStick.new(100.0, 0.1)
	s.press(Vector2.ZERO)
	s.drag(Vector2(55, 0))
	assert_almost_eq(s.value().x, 0.5, 0.01)

func test_release_resets() -> void:
	var s := VirtualStick.new(100.0)
	s.press(Vector2.ZERO)
	s.drag(Vector2(80, 0))
	s.release()
	assert_eq(s.value(), Vector2.ZERO)
