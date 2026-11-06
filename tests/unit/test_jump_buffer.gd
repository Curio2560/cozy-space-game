extends GutTest

func test_press_gives_one_jump() -> void:
	var j := JumpBuffer.new()
	j.update(true, 0.016)
	assert_true(j.consume())
	assert_false(j.consume(), "o mesmo toque não pode dar dois saltos")

func test_holding_does_not_repeat() -> void:
	var j := JumpBuffer.new()
	j.update(true, 0.016)
	j.consume()
	for i in 10:
		j.update(true, 0.016)
	assert_false(j.consume())

func test_press_just_before_landing_still_jumps() -> void:
	var j := JumpBuffer.new()
	j.update(true, 0.016)
	j.update(false, 0.05) # ainda no ar
	assert_true(j.consume())

func test_old_press_expires() -> void:
	var j := JumpBuffer.new()
	j.update(true, 0.016)
	for i in 20:
		j.update(false, 0.016)
	assert_false(j.consume())
