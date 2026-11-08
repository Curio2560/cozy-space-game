extends GutTest

func _same(a: PlanetData, b: PlanetData) -> bool:
	if a.placements.size() != b.placements.size():
		return false
	for i in a.placements.size():
		var p: Dictionary = a.placements[i]
		var q: Dictionary = b.placements[i]
		if p.kind != q.kind or not p.dir.is_equal_approx(q.dir) or not is_equal_approx(p.size, q.size):
			return false
	for i in a.posts.size():
		if not a.posts[i].is_equal_approx(b.posts[i]):
			return false
	return a.outpost_dir.is_equal_approx(b.outpost_dir)

func test_same_seed_gives_same_planet() -> void:
	assert_true(_same(PlanetGenerator.generate(42), PlanetGenerator.generate(42)))

func test_same_seed_gives_same_terrain() -> void:
	var a := PlanetGenerator.generate(7)
	var b := PlanetGenerator.generate(7)
	for d in PlanetGenerator.fibonacci_dirs(50):
		assert_almost_eq(a.height_at(d), b.height_at(d), 0.0001)

func test_different_seeds_give_different_planets() -> void:
	assert_false(_same(PlanetGenerator.generate(1), PlanetGenerator.generate(2)))

func test_three_posts_far_apart() -> void:
	for s in [1, 2, 3, 99, 1234]:
		var d := PlanetGenerator.generate(s)
		assert_eq(d.posts.size(), 3)
		for i in 3:
			for j in range(i + 1, 3):
				var arc := d.arc_m(d.posts[i], d.posts[j])
				# Três pontos o mais afastados possível na esfera ficam a ~120° (~125 m com raio 60).
				assert_gt(arc, d.radius * deg_to_rad(90.0), "seed %d: postos %d e %d só a %.0f m" % [s, i, j, arc])

func test_outpost_and_lair_exist_away_from_posts() -> void:
	var d := PlanetGenerator.generate(5)
	assert_almost_eq(d.outpost_dir.length(), 1.0, 0.001)
	assert_almost_eq(d.lair_dir.length(), 1.0, 0.001)
	for p in d.posts:
		assert_gt(d.arc_m(p, d.outpost_dir), 40.0)
		assert_gt(d.arc_m(p, d.lair_dir), 40.0)
	assert_gt(d.arc_m(d.outpost_dir, d.lair_dir), 40.0)

func test_spots_are_flat() -> void:
	var d := PlanetGenerator.generate(11)
	for p in d.posts + [d.outpost_dir]:
		assert_lt(d.slope_deg(p), 3.0, "posto não está plano")

func test_props_do_not_overlap() -> void:
	var d := PlanetGenerator.generate(3)
	var n := d.placements.size()
	assert_gt(n, 500, "poucos objetos colocados")
	for i in n:
		var a: Dictionary = d.placements[i]
		for j in range(i + 1, n):
			var b: Dictionary = d.placements[j]
			var dist: float = (a.dir * d.radius).distance_to(b.dir * d.radius)
			if dist < a.clear + b.clear - 0.001:
				fail_test("sobreposição: %s e %s a %.2f m" % [a.kind, b.kind, dist])
				return
	pass_test("sem sobreposições")

func test_props_keep_out_of_spots_and_steep_slopes() -> void:
	var d := PlanetGenerator.generate(8)
	for p in d.placements:
		assert_lte(d.slope_deg(p.dir), PlanetGenerator.MAX_SLOPE_DEG + 0.01)
		for s in d.flat_spots:
			assert_gte(d.arc_m(p.dir, s.dir), s.angle * d.radius, "%s dentro de uma zona livre" % p.kind)

func test_terrain_height_stays_within_amplitude() -> void:
	var d := PlanetGenerator.generate(13)
	for dir in PlanetGenerator.fibonacci_dirs(400):
		assert_lte(absf(d.base_height_at(dir)), d.height_amp + 0.001)

func test_density_scales_with_planet_area() -> void:
	var small := PlanetGenerator.generate(4, "prado", 40.0)
	var big := PlanetGenerator.generate(4, "prado", 80.0)
	assert_gt(big.placements.size(), small.placements.size() * 2.5)
