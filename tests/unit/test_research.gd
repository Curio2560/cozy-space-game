extends GutTest
## Pesquisa (#51): compras atómicas com dados, efeitos no mech, torres e edifícios, save,
## passa de planeta para planeta.

func test_buy_with_data_atomic_and_capped() -> void:
	var r := Research.new()
	var w := Wallet.new()
	w.add(Wallet.DATA, 10)
	assert_true(r.buy("mech_damage", w))
	assert_eq(w.amount(Wallet.DATA), 2)
	assert_false(r.buy("mech_damage", w), "faltam dados")
	assert_eq(r.level("mech_damage"), 1)
	w.add(Wallet.DATA, 500)
	assert_true(r.buy("turret_4", w))
	assert_false(r.buy("turret_4", w), "só um nível")
	assert_eq(r.max_turret_level(), 4)
	assert_gt(r.mech_damage_factor(), 1.0)

func test_outpost_hp_factor_keeps_fraction() -> void:
	var o := Outpost.new()
	var w := Wallet.new()
	w.add(Wallet.CREDITS, 500)
	o.build(0, "miner", w)
	o.damage(0, 50.0)
	o.set_hp_factor(1.3)
	assert_almost_eq(o.max_hp(0), 130.0, 0.01)
	assert_almost_eq(o.hp(0), 65.0, 0.01, "metade continua metade")

func test_turret_level_4_needs_research() -> void:
	var o := Outpost.new()
	var w := Wallet.new()
	w.add(Wallet.CREDITS, 9000)
	w.add(Wallet.ORE, 50)
	w.add(Wallet.CRYSTAL, 50)
	o.build(0, "turret", w)
	o.upgrade(0, w)
	o.upgrade(0, w)
	assert_false(o.upgrade(0, w), "sem pesquisa fica no 3")
	o.max_turret_level = 4
	assert_true(o.upgrade(0, w))
	assert_eq(o.level(0), 4)

func test_effects_in_game_and_kept_across_planets() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	run.wallet.add(Wallet.DATA, 200)
	assert_true(run.buy_research("mech_armor"))
	assert_true(run.buy_research("building_hp"))
	assert_almost_eq(run.mech.max_health, Mech.MAX_HEALTH * 1.25, 0.01)
	assert_eq(run.mech.health, run.mech.max_health)
	assert_almost_eq(run.outpost.state.hp_factor, 1.3, 0.01)
	run.arrive(run.galaxy.next_options()[0])
	await wait_physics_frames(2)
	assert_eq(run.research.level("mech_armor"), 1, "a pesquisa fica")
	assert_almost_eq(run.outpost.state.hp_factor, 1.3, 0.01, "o posto novo também tem")
	var saved: Dictionary = run.save_state()
	assert_eq(int(saved.research.mech_armor), 1)
