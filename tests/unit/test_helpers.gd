extends GutTest
## Mechs ajudantes (#59): construir (pesquisa + peças), colher e regar de dia, disparar à noite,
## save e viagem.

func _run() -> Node3D:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	return run

func _unlock(run: Node3D) -> void:
	run.wallet.add(Wallet.DATA, 100)
	run.wallet.add(Wallet.PARTS, 30)
	run.wallet.add(Wallet.CREDITS, 2000)
	assert_true(run.buy_research("factory"))
	assert_true(run.buy_research("helpers"))

func test_build_needs_research_and_parts() -> void:
	var run: Node3D = await _run()
	run.wallet.add(Wallet.PARTS, 30)
	run.wallet.add(Wallet.CREDITS, 2000)
	assert_false(run.build_helper(), "sem pesquisa")
	_unlock(run)
	var parts: int = run.wallet.amount(Wallet.PARTS)
	assert_true(run.build_helper())
	assert_eq(run.wallet.amount(Wallet.PARTS), parts - int(HelperSquad.COST[Wallet.PARTS]))
	assert_eq(run.helpers.helpers.size(), 1)
	run.build_helper()
	run.build_helper()
	assert_false(run.build_helper(), "no máximo 3")

func test_day_harvest_and_water() -> void:
	var run: Node3D = await _run()
	_unlock(run)
	run.build_helper()
	run.build_helper()
	var farm: Farm = run.farm.farm
	farm.plots[0] = {"crop": "fast", "t": 9999.0}
	farm.plots[1] = {"crop": "slow", "t": 0.0}
	var crops: int = run.wallet.crops_total()
	await wait_seconds(14.0)
	assert_gt(run.wallet.crops_total(), crops, "um ajudante colheu o talhão pronto")
	assert_gt(float(farm.plots[1].t), HelperSquad.WATER_BONUS * 0.9, "outro regou o que cresce")

func test_night_shoots_raiders() -> void:
	var run: Node3D = await _run()
	_unlock(run)
	run.build_helper()
	run.cycle.skip_to_night()
	run.defense.waves.launch_next()
	var c: Creature = run.defense.raiders[0]
	c.raid_target = func() -> Array: return []
	var h: Node3D = run.helpers.helpers[0].node
	var hd: Vector3 = run.planet.to_local(h.global_position).normalized()
	c.teleport_to(hd.rotated(SphereMath.basis_from_up(hd).x, 8.0 / run.planet.data.radius))
	var hp := c.health
	await wait_seconds(2.0)
	assert_lt(c.health, hp, "o ajudante dispara à noite")

func test_saved_and_kept_across_planets() -> void:
	var run: Node3D = await _run()
	_unlock(run)
	run.build_helper()
	assert_eq(int(run.save_state().helpers.count), 1)
	run.arrive(run.galaxy.next_options()[0])
	await wait_physics_frames(2)
	assert_eq(run.helpers.count, 1)
	assert_eq(run.helpers.helpers.size(), 1, "recriado no planeta novo")
