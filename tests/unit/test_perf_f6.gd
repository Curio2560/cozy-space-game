extends GutTest
## #56: decoração rala à volta do covil e da arena; qualidade da relva.

func test_decor_sparse_near_lair() -> void:
	var d := PlanetGenerator.generate(7, "prado")
	assert_almost_eq(PlanetGenerator.sparse_keep(d, d.lair_dir), PlanetGenerator.SPARSE_KEEP, 0.001)
	assert_eq(PlanetGenerator.sparse_keep(d, d.outpost_dir), 1.0)
	var near := 0
	var far := 0
	for p in d.placements:
		var m := minf(d.arc_m(p.dir, d.lair_dir), d.arc_m(p.dir, d.arena_dir))
		if m < PlanetGenerator.SPARSE_M:
			near += 1
		elif m > PlanetGenerator.SPARSE_FADE_M and m < PlanetGenerator.SPARSE_FADE_M + 25.0:
			far += 1
	assert_lt(near, far, "menos decoração junto ao covil do que no anel à volta")

func test_turf_visible_count() -> void:
	assert_eq(Planet.turf_visible_count(100, 1.0), 100)
	assert_eq(Planet.turf_visible_count(100, 0.35), 35)
	assert_eq(Planet.turf_visible_count(0, 0.5), 0)

func test_grass_setting_changes_drawn_turf() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	var full: int = run.planet.turf_visible_total()
	assert_gt(full, 0)
	run.planet.set_grass_factor(Settings.GRASS["low"])
	assert_lt(run.planet.turf_visible_total(), full * 0.5)
	run.planet.set_grass_factor(1.0)
	assert_eq(run.planet.turf_visible_total(), full)
