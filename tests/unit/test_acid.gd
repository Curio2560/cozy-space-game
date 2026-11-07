extends GutTest
## Bioma ácido (#20): rios com pontes, O₂ do ar e junto aos rios, bolhas, dano no ácido.

var d: PlanetData

func before_all() -> void:
	d = PlanetGenerator.generate(2, "acido")

func test_acid_planet_has_rivers_bridges_and_bubbles() -> void:
	assert_gt(d.rivers.size(), 3)
	assert_gt(d.bridges.size(), 0)
	assert_gt(d.o2_bubbles.size(), 10)

func test_rivers_are_deterministic() -> void:
	var e := PlanetGenerator.generate(2, "acido")
	assert_eq(e.rivers.size(), d.rivers.size())
	for i in d.rivers.size():
		assert_true((e.rivers[i].points[0] as Vector3).is_equal_approx(d.rivers[i].points[0]))

func test_meadow_has_no_rivers_and_lava_no_bubbles() -> void:
	var p := PlanetGenerator.generate(2, "prado")
	assert_eq(p.rivers.size(), 0)
	assert_eq(p.o2_bubbles.size(), 0)
	assert_eq(PlanetGenerator.generate(2, "lava").o2_bubbles.size(), 0)

func test_rivers_keep_out_of_spots() -> void:
	for river in d.rivers:
		for p: Vector3 in river.points:
			for s in d.flat_spots:
				assert_gt(d.arc_m(p, s.dir), s.angle * d.radius)

func test_roads_never_touch_acid() -> void:
	# Onde uma estrada cruza um rio há uma ponte.
	for road in d.roads:
		for p: Vector3 in road.points:
			assert_false(d.in_acid(p), "estrada dentro do ácido sem ponte")

func test_middle_of_river_is_acid() -> void:
	var found := false
	for river in d.rivers:
		var pts: PackedVector3Array = river.points
		var p := pts[pts.size() / 2]
		if d.bridge_clearance(p) > 0.0:
			assert_true(d.in_acid(p))
			found = true
	assert_true(found)

func test_o2_drains_more_near_rivers() -> void:
	var river: Dictionary = d.rivers[0]
	var p: Vector3 = river.points[river.points.size() / 2]
	var far := Vector3.ZERO
	for dir in PlanetGenerator.fibonacci_dirs(400):
		if d.river_clearance(dir) > 20.0:
			far = dir
			break
	assert_almost_eq(AcidHazard.o2_drain(d, far, 1.0), 1.0, 0.001)
	assert_gt(AcidHazard.o2_drain(d, p, 1.0), 1.0 + AcidHazard.NEAR_RIVER_DRAIN * 0.9)

func test_acid_hurts_on_foot_and_rover_only_inside() -> void:
	var river: Dictionary = d.rivers[1]
	var p: Vector3 = river.points[river.points.size() / 2]
	if d.bridge_clearance(p) <= 0.0:
		pass_test("ponto em cima de uma ponte")
		return
	assert_gt(AcidHazard.foot_damage_rate(d, p), 0.0)
	assert_gt(AcidHazard.rover_damage_rate(d, p), 0.0)
	assert_eq(AcidHazard.foot_damage_rate(d, d.outpost_dir), 0.0)

func test_bubbles_are_dry_and_spread() -> void:
	for i in d.o2_bubbles.size():
		assert_false(d.in_acid(d.o2_bubbles[i]))
		for j in range(i + 1, d.o2_bubbles.size()):
			assert_gt(d.arc_m(d.o2_bubbles[i], d.o2_bubbles[j]), 7.9)

func test_bubble_gives_o2_once_then_respawns() -> void:
	var b := O2Bubbles.new()
	add_child_autofree(b)
	b.setup(d)
	var pos := d.surface_point(d.o2_bubbles[0]) + d.o2_bubbles[0] * 1.0
	assert_eq(b.collect(pos), AcidHazard.BUBBLE_O2)
	assert_eq(b.collect(pos), 0.0)
	b._process(AcidHazard.BUBBLE_RESPAWN_S + 0.1)
	assert_eq(b.collect(pos), AcidHazard.BUBBLE_O2)

func test_vitals_lose_health_in_acid() -> void:
	var v := PlayerVitals.new()
	v.damage(AcidHazard.FOOT_ACID_DPS * 1.0)
	assert_almost_eq(v.health, PlayerVitals.MAX_HEALTH - AcidHazard.FOOT_ACID_DPS, 0.001)

func test_every_acid_river_starts_at_a_mountain() -> void:
	for s in [1, 7, 42]:
		var e := PlanetGenerator.generate(s, "acido")
		assert_gt(e.rivers.size(), 3)
		for rv in e.rivers:
			var p0: Vector3 = rv.points[0]
			var near := false
			for r in e.reliefs:
				if e.arc_m(p0, r.dir) < ReliefKit.piece(r.kind).radius * float(r.scale) + 2.0:
					near = true
			assert_true(near, "rio que não nasce numa montanha (seed %d)" % s)
