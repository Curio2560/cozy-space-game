extends GutTest
## Ecrã da manhã e recompensas (#42): pagamento por vaga, bónus da noite perfeita, resumo,
## relógio parado até começar o dia, trocar tripulante, aceitar encomenda, plantar.

func test_rewards_grow_with_night_and_wave() -> void:
	assert_gt(NightWaves.wave_reward(3, 1)[Wallet.CREDITS], NightWaves.wave_reward(1, 1)[Wallet.CREDITS])
	assert_gt(NightWaves.wave_reward(1, 3)[Wallet.CREDITS], NightWaves.wave_reward(1, 1)[Wallet.CREDITS])
	assert_gte(NightWaves.wave_reward(1, 1)[Wallet.DATA], 1)
	assert_gt(NightWaves.perfect_bonus(2)[Wallet.CREDITS], 0)

func test_summary_text() -> void:
	var t := MorningScreen.summary_text({"night": 1, "cleared": 2, "waves": 3, "damage": 12.0, "broken": 1, "credits": 90, "data": 2, "perfect": false})
	assert_string_contains(t, "2/3")
	assert_string_contains(t, "90")
	assert_eq(MorningScreen.summary_text({}), "")

func _run() -> Node3D:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	return run

func _clear_night(run: Node3D) -> void:
	for w in NightWaves.WAVES:
		run.defense.waves.launch_next()
		for c in run.defense.raiders.duplicate():
			c.take_hit(9999.0)

func test_perfect_night_pays_waves_and_bonus_then_morning_screen() -> void:
	var run: Node3D = await _run()
	run.cycle.skip_to_night()
	var before: int = run.wallet.credits()
	_clear_night(run)
	var waves_pay := 0
	for w in NightWaves.WAVES:
		waves_pay += int(NightWaves.wave_reward(1, w + 1)[Wallet.CREDITS])
	assert_eq(run.wallet.credits(), before + waves_pay, "cada vaga paga logo")
	run.cycle.skip_to_morning()
	assert_true(run.morning_open)
	assert_true(run.morning_screen.visible)
	assert_true(run.cycle.paused, "o relógio pára")
	var r: Dictionary = run.morning_screen.report
	assert_true(r.perfect)
	assert_eq(r.cleared, 3)
	assert_eq(run.wallet.credits(), before + waves_pay + int(NightWaves.perfect_bonus(1)[Wallet.CREDITS]))
	assert_eq(r.credits, waves_pay + int(NightWaves.perfect_bonus(1)[Wallet.CREDITS]))
	assert_gt(run.wallet.amount(Wallet.DATA), 0)
	var t: float = run.cycle.time
	await wait_physics_frames(10)
	assert_eq(run.cycle.time, t)
	run.close_morning()
	assert_false(run.cycle.paused)
	assert_true(run.player.controllable)

func test_damage_spoils_perfect_night() -> void:
	var run: Node3D = await _run()
	run.wallet.add(Wallet.CREDITS, 500)
	run.outpost.build(0, "solar")
	run.cycle.skip_to_night()
	run.defense.waves.launch_next()
	run.defense._on_raid_hit(run.defense.raiders[0], 0)
	for c in run.defense.raiders.duplicate():
		c.take_hit(9999.0)
	_clear_night(run)
	run.cycle.skip_to_morning()
	assert_false(run.morning_screen.report.perfect)
	assert_gt(run.morning_screen.report.damage, 0.0)

func test_morning_choices_crew_order_and_planting() -> void:
	var run: Node3D = await _run()
	run.wallet.add(Wallet.CREDITS, 200)
	run.open_morning({"night": 1, "cleared": 3, "waves": 3, "damage": 0.0, "broken": 0, "credits": 0, "data": 0, "perfect": false})
	run.crew.select("RaeTheRedPanda")
	assert_eq(run.mech.crew, "RaeTheRedPanda", "o mech troca com o tripulante")
	var o: DeliveryOrder = run.deliveries.session.offers[0]
	o.crop = ""
	assert_true(run.deliveries.accept(o))
	var n: int = run.morning_screen.plant_all("fast")
	assert_eq(n, run.farm.plot_total())
	assert_eq(run.farm.farm.state(0), "growing")
	run.morning_screen.refresh()
	run.close_morning()
	assert_false(run.morning_open)
