extends GutTest
## Estradas (estilo Google Earth): a volta principal passa em frente às casas, há uma praça à
## volta da base com estradas para cada casa, secundárias e caminhos mais estreitos; nada nasce em
## cima delas; nenhuma estrada passa por cima de uma estrutura; determinístico.

var d: PlanetData

func before_all() -> void:
	d = PlanetGenerator.generate(5)

func _passes_near(dir: Vector3, metres: float, main_only := true) -> bool:
	for r in d.roads:
		if main_only and not r.main:
			continue
		for p: Vector3 in r.points:
			if d.arc_m(p, dir) < metres:
				return true
	return false

func test_main_road_passes_in_front_of_every_post() -> void:
	assert_eq(d.post_doors.size(), d.posts.size())
	for door in d.post_doors:
		assert_true(_passes_near(door, 2.5), "a estrada principal devia passar à porta de cada posto")

func test_plaza_ring_around_the_base() -> void:
	var ring := d.roads.filter(func(r: Dictionary) -> bool: return r.get("closed", false))
	assert_eq(ring.size(), 1, "devia haver uma praça circular à volta da base")
	for p: Vector3 in ring[0].points:
		assert_almost_eq(d.arc_m(p, d.outpost_dir), d.plaza_radius_m, 0.5)

func test_a_road_reaches_the_lair_door() -> void:
	assert_true(_passes_near(d.lair_door, 2.5, false))

func test_secondary_roads_are_narrower() -> void:
	var side := d.roads.filter(func(r: Dictionary) -> bool: return not r.main)
	assert_gte(side.size(), 4)
	for r in side:
		assert_lt(r.width, PlanetGenerator.MAIN_ROAD_WIDTH)

func test_no_road_over_any_structure() -> void:
	for r in d.roads:
		var hw: float = r.width * 0.5
		for p: Vector3 in r.points:
			for st in PlanetGenerator.structures(d):
				assert_gt(d.arc_m(p, st[0]), st[1] + hw * 0.5, "estrada por cima de uma estrutura")

func test_many_branching_roads() -> void:
	assert_gte(d.roads.size(), 20, "devia haver muitos caminhos")
	var paths := d.roads.filter(func(r: Dictionary) -> bool: return r.width <= PlanetGenerator.PATH_WIDTH)
	assert_gte(paths.size(), 4, "devia haver caminhos pequenos")

func test_roads_are_continuous() -> void:
	for r in d.roads:
		var pts: PackedVector3Array = r.points
		for i in pts.size() - 1:
			assert_lt(d.arc_m(pts[i], pts[i + 1]), PlanetGenerator.ROAD_STEP_M * 2.0, "salto numa estrada")

func test_nothing_grows_on_roads() -> void:
	for p in d.placements:
		assert_gte(d.road_clearance(p.dir), p.clear - 0.01, "%s em cima de uma estrada" % p.kind)
	for i in range(0, d.turf_dirs.size(), 7):
		assert_gte(d.road_clearance(d.turf_dirs[i]), 0.19, "relva em cima de uma estrada")

func test_road_clearance_is_negative_on_the_road() -> void:
	var pts: PackedVector3Array = d.roads[0].points
	assert_lt(d.road_clearance(pts[pts.size() / 2]), 0.0)

func test_roads_are_deterministic() -> void:
	var again := PlanetGenerator.generate(5)
	assert_eq(again.roads.size(), d.roads.size())
	for i in d.roads.size():
		assert_eq((again.roads[i].points as PackedVector3Array).size(), (d.roads[i].points as PackedVector3Array).size())
		assert_true((again.roads[i].points[3] as Vector3).is_equal_approx(d.roads[i].points[3]))

func test_planet_builds_road_mesh_above_ground() -> void:
	var p := Planet.new()
	p.culling_enabled = false
	add_child(p)
	p.build(d)
	assert_not_null(p.roads_mesh)
	var arr := p.roads_mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in range(0, verts.size(), 11):
		var dir := verts[i].normalized()
		assert_gt(verts[i].length(), d.radius + d.height_at(dir), "estrada abaixo do chão")
	p.free()
