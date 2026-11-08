extends GutTest
## Torres laser (#40): construir, melhorar (3 níveis, atómico), energia, save; no jogo apontam e matam.

func _rich() -> Wallet:
	var w := Wallet.new()
	w.add(Wallet.CREDITS, 5000)
	w.add(Wallet.ORE, 50)
	w.add(Wallet.CRYSTAL, 20)
	return w

func test_build_and_upgrade_to_three() -> void:
	var o := Outpost.new()
	var w := _rich()
	assert_true(o.build(0, "turret", w))
	assert_eq(o.level(0), 1)
	assert_eq(o.turrets(), [0] as Array[int])
	assert_true(o.upgrade(0, w))
	assert_eq(o.level(0), 2)
	assert_true(o.upgrade(0, w))
	assert_eq(o.level(0), 3)
	assert_false(o.upgrade(0, w), "nível máximo")
	assert_true(o.upgrade_cost(0).is_empty())
	assert_gt(o.turret_stats(0).damage, Outpost.TURRET_LEVELS[0].damage)

func test_upgrade_is_atomic_and_only_for_turrets() -> void:
	var o := Outpost.new()
	var w := Wallet.new()
	w.add(Wallet.CREDITS, 500)
	assert_true(o.build(0, "turret", w))
	assert_true(o.build(1, "solar", w))
	assert_false(o.upgrade(1, w), "só torres")
	assert_false(o.upgrade(0, w), "falta minério")
	assert_eq(w.credits(), 220, "nada gasto")
	assert_eq(o.level(0), 1)

func test_low_power_slows_fire() -> void:
	var o := Outpost.new()
	var w := _rich()
	o.build(0, "turret", w)
	o.build(1, "solar", w)
	var fast: float = o.turret_stats(0).interval
	assert_eq(fast, Outpost.TURRET_LEVELS[0].interval)
	o.build(2, "miner", w)
	o.build(3, "miner", w)
	o.build(4, "miner", w) # 4 de procura, 3 de oferta
	assert_lt(o.power_factor(), 1.0)
	assert_gt(o.turret_stats(0).interval, fast, "sem energia dispara mais devagar")
	o.build(5, "solar", w)
	assert_eq(o.turret_stats(0).interval, fast)

func test_level_saved() -> void:
	var o := Outpost.new()
	var w := _rich()
	o.build(2, "turret", w)
	o.upgrade(2, w)
	var p := Outpost.new()
	p.from_dict(JSON.parse_string(JSON.stringify(o.to_dict())))
	assert_eq(p.level(2), 2)
	assert_eq(p.level(0), 1)

func test_turret_shoots_raider_in_game() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	run.wallet.add(Wallet.CREDITS, 1000)
	assert_true(run.outpost.build(0, "turret"))
	var head: Node3D = run.outpost.turret_heads.get(0)
	assert_not_null(head)
	run.cycle.skip_to_night()
	run.defense.waves.launch_next()
	var c: Creature = run.defense.raiders[0]
	var d: PlanetData = run.planet.data
	c.teleport_to(d.toward_point(d.outpost_slots[0], d.outpost_dir, 10.0))
	c.raid_target = func() -> Array: return [] # fica parada a passear
	var hp := c.health
	await wait_physics_frames(40)
	assert_lt(c.health, hp, "a torre acerta")
	var t := c.global_position - head.global_position
	var u := head.global_basis.y.normalized()
	t = (t - u * t.dot(u)).normalized()
	assert_gt((-head.global_basis.x.normalized()).dot(t), 0.9, "a cabeça aponta para a criatura")
