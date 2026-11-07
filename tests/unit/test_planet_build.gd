extends GutTest
## Construção da cena do planeta e culling por hemisfério.

var planet: Planet

func before_all() -> void:
	planet = Planet.new()
	planet.culling_enabled = false
	add_child(planet)
	planet.build(PlanetGenerator.generate(21))

func after_all() -> void:
	planet.free()

func test_every_placement_becomes_an_instance() -> void:
	assert_eq(planet.prop_instance_count(), planet.data.placements.size())

func test_ground_collision_at_surface() -> void:
	await wait_physics_frames(2)
	var space := planet.get_world_3d().direct_space_state
	for dir in [Vector3.UP, Vector3(1, 0.3, -0.2).normalized(), planet.data.posts[0]]:
		var q := PhysicsRayQueryParameters3D.create(dir * 200.0, Vector3.ZERO)
		var hit := space.intersect_ray(q)
		assert_false(hit.is_empty(), "sem colisão na direção %s" % dir)
		if not hit.is_empty():
			var expected := planet.data.radius + planet.data.height_at(dir)
			# O raio pode bater numa árvore/casa; nunca abaixo do terreno.
			assert_gte((hit.position as Vector3).length(), expected - 0.5)

func test_post_markers_exist() -> void:
	for i in 3:
		assert_not_null(planet.get_node_or_null("Post%d" % i))
	assert_not_null(planet.get_node_or_null("Outpost"))
	assert_not_null(planet.get_node_or_null("Lair"))

func test_culling_hides_far_side_and_shows_near_side() -> void:
	planet.update_culling(Vector3(0, 0, 120))
	var visible := planet.visible_region_count()
	assert_gt(visible, 2)
	assert_lt(visible, planet.get_children().filter(func(c: Node) -> bool: return c.name.begins_with("Region")).size(), "o lado de trás devia estar escondido")

func test_regions_cover_the_whole_sphere() -> void:
	# Qualquer ponto da esfera está dentro do ângulo de alguma região.
	var dirs := Icosphere.region_dirs(Planet.REGION_LEVEL)
	assert_eq(dirs.size(), 42)
	for p in PlanetGenerator.fibonacci_dirs(500):
		var best := PI
		for d in dirs:
			best = minf(best, p.angle_to(d))
		assert_lte(best, Planet.region_angle)

func test_tall_props_near_horizon_are_not_culled() -> void:
	# Câmara a 4 m da superfície; árvore de 4,6 m a 30 m de arco (para lá do horizonte do chão).
	var r := planet.data.radius
	var cam := Vector3(0, 0, r + 4.0)
	var tree_dir := Vector3(0, 0, 1).rotated(Vector3.UP, 30.0 / r)
	var tree_top := tree_dir * (r + 4.6)
	var horizon_ground := acos(r / (r + 4.0))
	assert_gt(tree_dir.angle_to(Vector3(0, 0, 1)), horizon_ground, "a árvore está mesmo para lá do horizonte do chão")
	assert_lt(tree_top.distance_to(cam), 40.0)
	planet.update_culling(cam)
	var dirs := Icosphere.region_dirs(Planet.REGION_LEVEL)
	var best := 0
	for i in dirs.size():
		if tree_dir.dot(dirs[i]) > tree_dir.dot(dirs[best]):
			best = i
	assert_true(planet.get_node("Region%d" % best).visible, "a região da árvore devia estar visível")

func test_region_visibility_math() -> void:
	var cam := Vector3(0, 0, 100.0)
	assert_true(PlanetCulling.region_visible(Vector3(0, 0, 1), cam, 60.0, 0.66))
	assert_false(PlanetCulling.region_visible(Vector3(0, 0, -1), cam, 60.0, 0.66))
	# À superfície o horizonte está quase a 0°: só regiões próximas são visíveis.
	var surf := Vector3(0, 0, 61.5)
	assert_true(PlanetCulling.region_visible(Vector3(0, 0, 1), surf, 60.0, 0.66))
	assert_false(PlanetCulling.region_visible(Vector3(1, 0, 0), surf, 60.0, 0.66))

func test_reliefs_have_mesh_and_collision_at_their_height() -> void:
	assert_eq(planet.relief_meshes.size(), planet.data.reliefs.size())
	await wait_physics_frames(2)
	var space := planet.get_world_3d().direct_space_state
	for r in planet.data.reliefs:
		var dir: Vector3 = planet.data.relief_dir(r, 0.37, 0.21) # fora de um vértice da malha
		var q := PhysicsRayQueryParameters3D.create(dir * 200.0, Vector3.ZERO)
		var hit := space.intersect_ray(q)
		assert_false(hit.is_empty(), "relevo %s sem colisão" % r.kind)
		if not hit.is_empty():
			# A colisão é a malha da peça; o mapa de alturas tem células de 0,5 m.
			assert_almost_eq((hit.position as Vector3).length(), planet.data.surface_point(dir).length(), 0.6, r.kind)

func test_acid_planet_builds_rivers_and_bridges_with_collision() -> void:
	var p := Planet.new()
	p.culling_enabled = false
	add_child_autofree(p)
	p.build(PlanetGenerator.generate(2, "acido"))
	assert_not_null(p.rivers_mesh)
	assert_eq(p.bridge_nodes.size(), p.data.bridges.size())
	await wait_physics_frames(2)
	var space := p.get_world_3d().direct_space_state
	var br: Dictionary = p.data.bridges[0]
	var mid: Vector3 = br.points[br.points.size() / 2]
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid * 200.0, Vector3.ZERO))
	assert_false(hit.is_empty())
	# O tabuleiro fica acima do chão.
	assert_gt((hit.position as Vector3).length(), p.data.surface_point(mid).length() + 0.1)
