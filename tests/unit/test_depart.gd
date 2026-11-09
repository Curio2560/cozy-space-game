extends GutTest
## Vitória e partida (#48): recompensa, nave na base depois do boss, diálogo de partida
## (vender tudo / partir / ficar), save do boss vencido.

func test_reward_grows() -> void:
	assert_gt(BossRules.reward(1)[Wallet.CREDITS], BossRules.reward(0)[Wallet.CREDITS])
	assert_gt(BossRules.reward(0)[Wallet.DATA], 0)

func test_left_value() -> void:
	var w := Wallet.new()
	w.add(Wallet.ORE, 10)
	w.add(Wallet.CROP_SLOW, 2)
	w.add(Wallet.DATA, 5)
	assert_eq(DepartDialog.left_value(w), 10 * Market.price(Wallet.ORE) + 2 * Market.price(Wallet.CROP_SLOW))

func _run() -> Node3D:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	return run

func test_win_pays_and_shows_ship() -> void:
	var run: Node3D = await _run()
	assert_null(run.dock.ship, "sem nave antes do boss")
	var c0: int = run.wallet.credits()
	run.boss_fight.beaten = true
	run._on_boss_won()
	assert_eq(run.wallet.credits(), c0 + int(BossRules.reward(0)[Wallet.CREDITS]))
	assert_not_null(run.dock.ship)
	assert_true(run.save_state().boss.beaten)
	run.player.place_at(run.dock.ship_position() + run.player.up() * 0.5 + run.dock.ship.global_basis.z * 4.0)
	await wait_physics_frames(2)
	assert_true(run.dock.near_ship())

func test_depart_choices() -> void:
	var run: Node3D = await _run()
	run.boss_fight.beaten = true
	run.dock.refresh()
	run.wallet.add(Wallet.ORE, 10)
	watch_signals(run.dock)
	run.dock.open()
	assert_true(run.dock.dialog.visible)
	run.dock._on_choice("stay")
	assert_signal_not_emitted(run.dock, "depart")
	assert_eq(run.wallet.amount(Wallet.ORE), 10)
	var c0: int = run.wallet.credits()
	run.dock._on_choice("sell")
	assert_signal_emitted(run.dock, "depart")
	assert_eq(run.wallet.amount(Wallet.ORE), 0)
	assert_eq(run.wallet.credits(), c0 + 10 * Market.price(Wallet.ORE))
