extends GutTest
## Ciclo dia/noite (#37): 7 + 3 min, aviso 30 s antes, eventos, luz, bónus noturno, save.

func test_starts_on_day_one_in_daylight() -> void:
	var c := DayCycle.new()
	assert_eq(c.day, 1)
	assert_false(c.is_night())
	assert_eq(c.time_to_night(), DayCycle.DAY_LEN)
	assert_eq(c.pay_factor(), 1.0)

func test_warning_then_night_then_morning() -> void:
	var c := DayCycle.new()
	watch_signals(c)
	c.tick(DayCycle.DAY_LEN - DayCycle.WARN_BEFORE - 1.0)
	assert_signal_not_emitted(c, "dusk_warning")
	c.tick(2.0)
	assert_signal_emit_count(c, "dusk_warning", 1)
	assert_false(c.is_night())
	c.tick(DayCycle.WARN_BEFORE)
	assert_true(c.is_night())
	assert_signal_emitted_with_parameters(c, "night_started", [1])
	assert_eq(c.pay_factor(), DayCycle.NIGHT_PAY)
	c.tick(DayCycle.NIGHT_LEN)
	assert_false(c.is_night())
	assert_eq(c.day, 2)
	assert_signal_emitted_with_parameters(c, "morning", [2])

func test_fast_time_never_skips_events() -> void:
	var c := DayCycle.new()
	watch_signals(c)
	c.speed = 50.0
	c.tick(DayCycle.CYCLE_LEN * 2.0 / 50.0 + 0.01) # dois ciclos de uma vez
	assert_signal_emit_count(c, "dusk_warning", 2)
	assert_signal_emit_count(c, "night_started", 2)
	assert_signal_emit_count(c, "morning", 2)
	assert_eq(c.day, 3)

func test_paused_does_not_advance() -> void:
	var c := DayCycle.new()
	c.paused = true
	c.tick(100.0)
	assert_eq(c.time, 0.0)

func test_daylight_full_by_day_dark_at_night_and_continuous() -> void:
	var c := DayCycle.new()
	c.time = 200.0
	assert_eq(c.daylight(), 1.0)
	c.time = DayCycle.DAY_LEN + 60.0
	assert_eq(c.daylight(), 0.0)
	var prev := -1.0
	var worst := 0.0
	var t := 0.0
	while t < DayCycle.CYCLE_LEN:
		c.time = t
		var v := c.daylight()
		if prev >= 0.0:
			worst = maxf(worst, absf(v - prev))
		prev = v
		t += 0.5
	c.time = 0.0
	worst = maxf(worst, absf(c.daylight() - prev)) # fim da noite → início do dia
	assert_lt(worst, 0.06, "sem saltos de luz")

func test_skip_to_night_and_morning() -> void:
	var c := DayCycle.new()
	watch_signals(c)
	c.skip_to_night()
	assert_true(c.is_night())
	assert_signal_emitted(c, "dusk_warning")
	assert_signal_emitted(c, "night_started")
	c.skip_to_morning()
	assert_false(c.is_night())
	assert_eq(c.day, 2)
	c.skip_to_morning() # de dia: passa pela noite e acaba na manhã seguinte
	assert_eq(c.day, 3)
	assert_signal_emit_count(c, "night_started", 2)

func test_save_round_trip() -> void:
	var c := DayCycle.new()
	c.tick(DayCycle.DAY_LEN + 10.0)
	var d := DayCycle.new()
	d.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.day, 1)
	assert_true(d.is_night())
	assert_almost_eq(d.time, c.time, 0.01)
	watch_signals(d)
	d.tick(1.0)
	assert_signal_not_emitted(d, "dusk_warning", "o aviso já tinha passado")

func test_night_delivery_pays_more() -> void:
	var w := Wallet.new()
	var s := DeliverySession.new(w, [[0.0, 100.0], [100.0, 0.0]], 3)
	var o := s.make_order(0, 1)
	s.offers = [o]
	s.accept(o)
	s.pick_up()
	s.pay_factor = 1.0
	var day_pay := DeliverySession.payment(o.base_pay, o.time_limit, 0.0)
	s.pay_factor = DayCycle.NIGHT_PAY
	var paid := s.deliver()
	assert_eq(paid, int(round(day_pay * DayCycle.NIGHT_PAY)))

func test_cycle_runs_in_game_and_is_saved() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	var day_energy: float = run.sun.light_energy
	run.cycle.skip_to_night()
	await wait_process_frames(5)
	assert_true(run.cycle.is_night())
	assert_lt(run.sun.light_energy, day_energy, "à noite há menos luz")
	assert_eq(run.deliveries.session.pay_factor, DayCycle.NIGHT_PAY)
	assert_true(run.save_state().has("cycle"))
	assert_true(run.day_clock.visible)

func test_invincible_toggle_blocks_damage() -> void:
	var v := PlayerVitals.new()
	v.invincible = true
	v.damage(50.0)
	assert_eq(v.health, PlayerVitals.MAX_HEALTH)
