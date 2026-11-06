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

func test_sky_planets_animate_and_follow_camera() -> void:
	var run := _run("prado")
	await wait_process_frames(2)
	var sp: SkyPlanets = run.sky_planets
	var s: Sprite3D = sp.get_child(0)
	var first := s.texture
	await wait_seconds(1.2)
	assert_ne(s.texture, first, "o planeta devia mudar de fotograma (rodar)")
	assert_almost_eq(sp.global_position.distance_to(run.camera.global_position), 0.0, 0.5)

func test_placing_rover_does_not_hurt_it() -> void:
	var run := _run("prado")
	await wait_physics_frames(90)
	assert_eq(run.rover.health, run.rover.max_health)
