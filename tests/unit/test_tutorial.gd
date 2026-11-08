extends GutTest
## Tutorial inicial e dicas de desbloqueio.

func test_steps_advance_when_done_and_skip() -> void:
	var t := Tutorial.new()
	var flags := [false, false]
	t.steps = [["A", func() -> bool: return flags[0]], ["B", func() -> bool: return flags[1]]]
	add_child_autofree(t)
	assert_eq(t.current_text_key(), "A")
	flags[0] = true
	t._process(0.1)
	assert_eq(t.current_text_key(), "B")
	t.skip_current()
	assert_false(t.in_intro())

func test_tips_show_once() -> void:
	var t := Tutorial.new()
	var on := [false]
	t.tips = [["TIP", func() -> bool: return on[0]]]
	add_child_autofree(t)
	t._process(0.1)
	assert_eq(t.current_text_key(), "")
	on[0] = true
	t._process(0.1)
	assert_eq(t.current_text_key(), "TIP")
	t._process(Tutorial.TIP_TIME + 1.0)
	t._process(0.1)
	assert_eq(t.current_text_key(), "", "não volta a aparecer")
	assert_true("TIP" in t.seen)

func test_save_round_trip() -> void:
	var t := Tutorial.new()
	t.steps = [["A", func() -> bool: return false], ["B", func() -> bool: return false]]
	add_child_autofree(t)
	t.step = 1
	t.seen.append("TIP_X")
	var u := Tutorial.new()
	u.steps = t.steps
	add_child_autofree(u)
	u.from_dict(t.to_dict())
	assert_eq(u.step, 1)
	assert_true("TIP_X" in u.seen)

func test_game_starts_with_the_intro() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(5)
	assert_eq(run.tutorial.current_text_key(), "TUT_MOVE")
	run._tut_walk = 10.0
	await wait_physics_frames(3)
	assert_eq(run.tutorial.current_text_key(), "TUT_JUMP")
