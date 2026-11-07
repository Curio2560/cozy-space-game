extends GutTest
## Relevo modular (#19): peças dobradas ao planeta, longe de postos e estradas, determinístico.

func test_eight_to_twelve_reliefs_per_planet() -> void:
	for s in [1, 2, 3, 99]:
		var d := PlanetGenerator.generate(s)
		assert_between(d.reliefs.size(), 8, 12, "seed %d" % s)

func test_reliefs_are_deterministic() -> void:
	var a := PlanetGenerator.generate(5, "lava")
	var b := PlanetGenerator.generate(5, "lava")
	assert_eq(a.reliefs.size(), b.reliefs.size())
	for i in a.reliefs.size():
		assert_eq(a.reliefs[i].kind, b.reliefs[i].kind)
		assert_true((a.reliefs[i].dir as Vector3).is_equal_approx(b.reliefs[i].dir))

func test_relief_raises_ground_at_its_peak() -> void:
	var d := PlanetGenerator.generate(3)
	var r: Dictionary = d.reliefs[0]
	var pc := ReliefKit.piece(r.kind)
	# Ponto mais alto do mapa de alturas da peça.
	var best := Vector2.ZERO
	var best_h := -1.0
	var n: int = pc.n
	for iz in n:
		for ix in n:
			var h: float = pc.grid[iz * n + ix]
			if h > best_h:
				best_h = h
				best = Vector2(ix * ReliefKit.CELL - pc.half, iz * ReliefKit.CELL - pc.half)
	var dir := d.relief_dir(r, best.x, best.y)
	assert_gt(d.relief_height(dir), 0.5)
	assert_almost_eq(d.height_at(dir), d.base_height_at(dir) + d.relief_height(dir), 0.0001)

func test_local_and_dir_are_inverse() -> void:
	var d := PlanetGenerator.generate(3)
	var r: Dictionary = d.reliefs[1]
	var l := d.relief_local(r, d.relief_dir(r, 3.0, -2.0))
	assert_almost_eq(l.x, 3.0, 0.001)
	assert_almost_eq(l.y, -2.0, 0.001)

func test_spots_and_roads_stay_flat() -> void:
	for s in [1, 7, 42]:
		var d := PlanetGenerator.generate(s, "acido")
		for sp in d.flat_spots:
			assert_eq(d.relief_height(sp.dir), 0.0, "zona livre com relevo (seed %d)" % s)
		for road in d.roads:
			for p: Vector3 in road.points:
				assert_eq(d.relief_height(p), 0.0, "estrada por cima de relevo (seed %d)" % s)

func test_relief_borders_sit_on_the_ground() -> void:
	for kind in ReliefKit.KINDS:
		var pc := ReliefKit.piece(kind)
		var border := ReliefKit.border_edges(pc)
		assert_gt(border.size(), 0, kind)
		for p in border:
			assert_lt(p.y, 0.05, "%s: borda acima do chão" % kind)
