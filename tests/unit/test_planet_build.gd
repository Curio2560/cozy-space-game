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
	assert_lt(visible, 12, "o lado de trás devia estar escondido")

func test_region_visibility_math() -> void:
	var cam := Vector3(0, 0, 100.0)
	assert_true(PlanetCulling.region_visible(Vector3(0, 0, 1), cam, 60.0, 0.66))
	assert_false(PlanetCulling.region_visible(Vector3(0, 0, -1), cam, 60.0, 0.66))
	# À superfície o horizonte está quase a 0°: só regiões próximas são visíveis.
	var surf := Vector3(0, 0, 61.5)
	assert_true(PlanetCulling.region_visible(Vector3(0, 0, 1), surf, 60.0, 0.66))
	assert_false(PlanetCulling.region_visible(Vector3(1, 0, 0), surf, 60.0, 0.66))
