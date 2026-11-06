extends GutTest
## Estradas: ligam o posto avançado aos postos e os postos entre si; há secundárias mais
## estreitas; nada nasce em cima delas; determinístico; a malha existe.

var d: PlanetData

func before_all() -> void:
	d = PlanetGenerator.generate(5)

func _ends(r: Dictionary) -> Array:
	var pts: PackedVector3Array = r.points
	return [pts[0], pts[pts.size() - 1]]

func _connects(a: Vector3, b: Vector3) -> bool:
	for r in d.roads:
		if not r.main:
			continue
		var e := _ends(r)
		if (e[0].angle_to(a) < 0.01 and e[1].angle_to(b) < 0.01) or (e[0].angle_to(b) < 0.01 and e[1].angle_to(a) < 0.01):
			return true
	return false

func test_main_roads_link_outpost_and_every_post() -> void:
	for p in d.posts:
		assert_true(_connects(d.outpost_dir, p), "falta a estrada base → posto")
	for i in d.posts.size():
		assert_true(_connects(d.posts[i], d.posts[(i + 1) % d.posts.size()]), "falta a estrada entre postos")

func test_secondary_roads_are_narrower_and_one_reaches_the_lair() -> void:
	var side := d.roads.filter(func(r: Dictionary) -> bool: return not r.main)
	assert_gte(side.size(), 4)
	for r in side:
		assert_lt(r.width, PlanetGenerator.MAIN_ROAD_WIDTH)
	var to_lair := side.any(func(r: Dictionary) -> bool: return (_ends(r)[1] as Vector3).angle_to(d.lair_dir) < 0.01)
	assert_true(to_lair, "devia haver uma estrada secundária até ao covil")

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
