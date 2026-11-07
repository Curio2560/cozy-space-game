extends GutTest
## Bioma lava (#21): fissuras pela seed, calor do rover, sobreaquecimento e arrefecimento.

func test_lava_planet_has_many_short_narrow_fissures() -> void:
	var d := PlanetGenerator.generate(4, "lava")
	assert_gt(d.rivers.size(), 8)
	for f in d.rivers:
		assert_lte(float(f.width), 2.0)
		var pts: PackedVector3Array = f.points
		assert_lt(d.arc_m(pts[0], pts[pts.size() - 1]), 45.0)

func test_fissures_are_deterministic() -> void:
	var a := PlanetGenerator.generate(4, "lava")
	var b := PlanetGenerator.generate(4, "lava")
	assert_eq(a.rivers.size(), b.rivers.size())
	assert_true((a.rivers[0].points[0] as Vector3).is_equal_approx(b.rivers[0].points[0]))

func test_fissures_do_not_drain_o2() -> void:
	var d := PlanetGenerator.generate(4, "lava")
	var p: Vector3 = d.rivers[0].points[d.rivers[0].points.size() / 2]
	assert_eq(AcidHazard.o2_drain(d, p, 0.0, 0.0), 0.0)

func test_heat_rises_with_speed_and_near_fissures() -> void:
	var fast := RoverHeat.new()
	var near := RoverHeat.new()
	for i in 10:
		fast.tick(0.5, 14.0, 1.0, INF, false)
		near.tick(0.5, 14.0, 1.0, 1.0, false)
	assert_gt(fast.heat, 0.0)
	assert_gt(near.heat, fast.heat)

func test_cools_when_parked_and_faster_in_shade() -> void:
	var sun := RoverHeat.new()
	var shade := RoverHeat.new()
	sun.heat = 80.0
	shade.heat = 80.0
	sun.tick(1.0, 0.0, 0.0, INF, false)
	shade.tick(1.0, 0.0, 0.0, INF, true)
	assert_lt(sun.heat, 80.0)
	assert_lt(shade.heat, sun.heat)

func test_overheat_slows_until_cooled() -> void:
	var h := RoverHeat.new()
	watch_signals(h)
	for i in 20:
		h.tick(0.5, 14.0, 1.0, -0.5, false) # dentro da fissura
	assert_true(h.hot)
	assert_signal_emitted(h, "overheated")
	assert_eq(h.speed_factor(), RoverHeat.OVERHEAT_SPEED)
	for i in 40:
		h.tick(0.5, 0.0, 0.0, INF, true)
	assert_false(h.hot)
	assert_eq(h.speed_factor(), 1.0)

func test_shade_next_to_trees() -> void:
	var d := PlanetGenerator.generate(4, "lava")
	var tree: Dictionary = {}
	for p in d.placements:
		if p.collider > 0.0:
			tree = p
			break
	assert_true(RoverHeat.in_shade(d, tree.dir))

func test_heat_bar_only_in_lava() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(5)
	assert_false(run.bars.is_shown("heat"))
	run.biome = "lava"
	run.start(4)
	run.enter_rover()
	await wait_physics_frames(5)
	assert_true(run.bars.is_shown("heat"))
