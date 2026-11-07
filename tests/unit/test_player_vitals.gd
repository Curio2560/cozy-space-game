extends GutTest

func test_starts_full() -> void:
	var v := PlayerVitals.new()
	assert_eq(v.health, PlayerVitals.MAX_HEALTH)
	assert_eq(v.o2, PlayerVitals.MAX_O2)

func test_o2_drains_and_recovers() -> void:
	var v := PlayerVitals.new()
	v.o2_drain = 10.0
	v.tick(2.0)
	assert_almost_eq(v.o2, 80.0, 0.01)
	v.o2_drain = 0.0
	v.tick(0.4)
	assert_almost_eq(v.o2, 90.0, 0.01)

func test_without_o2_health_drops_then_faints_once() -> void:
	var v := PlayerVitals.new()
	watch_signals(v)
	v.o2 = 0.0
	v.o2_drain = 5.0
	for i in 100:
		v.tick(0.1)
	assert_true(v.down)
	assert_eq(v.health, 0.0)
	assert_signal_emit_count(v, "fainted", 1)

func test_damage_and_regen_after_delay() -> void:
	var v := PlayerVitals.new()
	v.damage(40.0)
	assert_eq(v.health, 60.0)
	v.tick(2.0)
	assert_eq(v.health, 60.0, "ainda não regenera logo a seguir ao dano")
	v.tick(3.0)
	assert_gt(v.health, 60.0)

func test_bubble_adds_o2_capped() -> void:
	var v := PlayerVitals.new()
	v.o2 = 50.0
	v.add_o2(80.0)
	assert_eq(v.o2, PlayerVitals.MAX_O2)

func test_reset_after_faint() -> void:
	var v := PlayerVitals.new()
	v.damage(500.0)
	assert_true(v.down)
	v.reset()
	assert_false(v.down)
	assert_eq(v.health, PlayerVitals.MAX_HEALTH)
