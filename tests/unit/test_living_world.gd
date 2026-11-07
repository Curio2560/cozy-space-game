extends GutTest
## Mundo vivo (#24): vento na decoração, árvores pontilhadas no caminho, partículas por bioma.

func test_wind_per_prop_type() -> void:
	assert_eq(Planet.wind_for("rocks/SM_Rocks_01", 0.4), 0.0)
	assert_gt(Planet.wind_for("nature/BirchTree_1", 0.06), 0.0)
	assert_gt(Planet.wind_for("nature/Bush_1", 0.0), Planet.wind_for("nature/BirchTree_1", 0.06))
	assert_true(Planet.is_tree(0.06))
	assert_false(Planet.is_tree(0.4))

func test_tree_material_has_wind_and_fade_on_both_passes() -> void:
	var m := CelShading.vertex_color_material(true, 0.012, true)
	assert_eq(m.get_shader_parameter("wind_strength"), 0.012)
	assert_true(m.get_shader_parameter("fade_occluder"))
	var o := m.next_pass as ShaderMaterial
	assert_eq(o.get_shader_parameter("wind_strength"), 0.012)
	assert_true(o.get_shader_parameter("fade_occluder"))

func test_occlusion_positions_reach_tree_materials() -> void:
	var m := CelShading.vertex_color_material(true, 0.012, true)
	CelShading.set_occlusion(Vector3(1, 2, 3), Vector3(4, 5, 6))
	assert_eq(m.get_shader_parameter("occlude_from"), Vector3(1, 2, 3))
	assert_eq((m.next_pass as ShaderMaterial).get_shader_parameter("occlude_to"), Vector3(4, 5, 6))

func test_planet_trees_use_wind_material() -> void:
	var p := Planet.new()
	p.culling_enabled = false
	add_child_autofree(p)
	p.build(PlanetGenerator.generate(21))
	var windy := 0
	for r in p.get_children():
		if not r.name.begins_with("Region"):
			continue
		for mmi in r.get_children():
			if mmi is MultiMeshInstance3D and mmi.material_override is ShaderMaterial:
				var w = mmi.material_override.get_shader_parameter("wind_strength")
				if w != null and float(w) > 0.0:
					windy += 1
	assert_gt(windy, 0)

func test_ambient_particles_per_biome() -> void:
	for b in ["prado", "acido", "lava"]:
		var a := AmbientParticles.new()
		add_child_autofree(a)
		a.setup(b)
		assert_true(a.emitting, b)
		assert_eq(a.color_ramp.get_color(1), AmbientParticles.STYLES[b].color, b)

func test_only_fading_materials_use_the_discard_shader() -> void:
	assert_eq(CelShading.vertex_color_material(true, 0.012, true).shader, CelShading.CEL_FADE_SHADER)
	assert_eq(CelShading.vertex_color_material(true, 0.05, false).shader, CelShading.CEL_SHADER)
	assert_eq(CelShading.vertex_color_material(false).shader, CelShading.CEL_SHADER)
