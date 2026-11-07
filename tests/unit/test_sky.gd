extends GutTest
## Céu: shader com cores do bioma e planetas animados do Tiny Planet Pack.

func _run(biome: String) -> Node3D:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	run.biome = biome
	add_child_autofree(run)
	return run

func test_each_biome_has_its_sky_colours_and_planets() -> void:
	for biome: String in PlanetGenerator.BIOMES:
		var run := _run(biome)
		await wait_process_frames(2)
		var sky: Dictionary = PlanetGenerator.BIOMES[biome].sky
		assert_eq(run._env.background_mode, Environment.BG_SKY, biome)
		assert_eq((run._sky_mat.get_shader_parameter("base_color") as Color).to_html(), (sky.bg as Color).to_html(), biome)
		assert_eq(run.sky_planets.count(), (sky.planets as Array).size(), biome)
		run.free()

func test_sky_planets_rotate_smoothly_and_follow_camera() -> void:
	var run := _run("prado")
	await wait_process_frames(2)
	var sp: SkyPlanets = run.sky_planets
	var q: MeshInstance3D = sp.get_child(0)
	var m := q.material_override as ShaderMaterial
	assert_eq(m.shader, SkyPlanets.SHADER, "planeta com o shader 3D")
	assert_not_null(m.get_shader_parameter("map"))
	assert_true(q.mesh is SphereMesh, "planeta do céu é uma esfera 3D")
	# Roda à volta do seu eixo: a orientação muda com o tempo.
	var before := q.basis
	await wait_process_frames(30)
	assert_false(q.basis.is_equal_approx(before), "o planeta devia estar a rodar")
	assert_gt(sp.spin_speed(0), 0.0)
	assert_almost_eq(sp.global_position.distance_to(run.camera.global_position), 0.0, 0.5)

func test_placing_rover_does_not_hurt_it() -> void:
	var run := _run("prado")
	await wait_physics_frames(90)
	assert_eq(run.rover.health, run.rover.max_health)
