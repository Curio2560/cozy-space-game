extends GutTest
## Biomas: todos os modelos existem, todas as cores do pack de natureza têm paleta,
## e a pintura por paleta junta tudo numa superfície com a cor certa por vértice.

func _nature_kinds(biome: String) -> Array:
	var out := []
	for g in PlanetGenerator.BIOMES[biome].props:
		for k: String in g.kinds:
			if k not in out:
				out.append(k)
	return out

func test_every_biome_prop_loads() -> void:
	for biome: String in PlanetGenerator.BIOMES:
		for k: String in _nature_kinds(biome):
			var info := KitUtil.single_mesh(k)
			assert_not_null(info.mesh, "%s: %s não carrega" % [biome, k])

func test_every_nature_material_has_a_palette_colour() -> void:
	for biome: String in PlanetGenerator.BIOMES:
		var pal: Dictionary = PlanetGenerator.BIOMES[biome].palette
		for k: String in _nature_kinds(biome):
			var info := KitUtil.single_mesh(k)
			if not info.palette:
				continue
			var mesh: Mesh = info.mesh
			for i in mesh.get_surface_count():
				var mat := mesh.surface_get_material(i)
				assert_not_null(mat, "%s: %s superfície %d sem material (falta o .mtl?)" % [biome, k, i])
				if mat:
					var n := mat.resource_name.get_slice(".", 0)
					assert_true(pal.has(n), "%s: cor '%s' de %s não está na paleta" % [biome, n, k])

func test_user_grass_is_used_and_recoloured_per_biome() -> void:
	var cols := {}
	for biome: String in PlanetGenerator.BIOMES:
		assert_true(_nature_kinds(biome).has("mdvl/mdvl_nature_grass_01"), "%s sem a relva do utilizador" % biome)
		var info := KitUtil.single_mesh("mdvl/mdvl_nature_grass_01")
		var target: Color = PlanetGenerator.BIOMES[biome].palette.Grass
		var m := CelShading.recolor_textured_mesh(info.mesh, info.texture, target)
		assert_eq(m.get_surface_count(), 1)
		var c: PackedColorArray = m.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var avg := Color(0, 0, 0)
		for x in c:
			avg += x
		avg /= c.size()
		cols[biome] = avg
		# A média fica perto da cor do bioma (a variação de claro/escuro mantém-se à volta dela).
		assert_almost_eq(avg.r, target.r, 0.12, biome)
		assert_almost_eq(avg.g, target.g, 0.12, biome)
	assert_ne(cols.prado.to_html(), cols.lava.to_html())

func test_palette_mesh_is_one_surface_with_palette_colours() -> void:
	var src: Mesh = load("res://assets/nature/BirchTree_1.obj")
	var pal: Dictionary = PlanetGenerator.BIOMES["acido"].palette
	var m := CelShading.palette_mesh(src, pal)
	assert_eq(m.get_surface_count(), 1)
	var total := 0
	for i in src.get_surface_count():
		total += (src.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var arr := m.surface_get_arrays(0)
	assert_eq((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), total)
	var colors: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var seen := {}
	for c in colors:
		seen[c.to_html(false)] = true
	assert_true(seen.has((pal["Green"] as Color).to_html(false)), "falta o verde da paleta ácida")
	assert_true(seen.has((pal["White"] as Color).to_html(false)), "falta o branco da paleta ácida")
	assert_eq(CelShading.palette_mesh(src, pal), m, "devia vir da cache")

func test_same_model_differs_between_biomes() -> void:
	var src: Mesh = load("res://assets/nature/Bush_1.obj")
	var a := CelShading.palette_mesh(src, PlanetGenerator.BIOMES["prado"].palette)
	var b := CelShading.palette_mesh(src, PlanetGenerator.BIOMES["lava"].palette)
	assert_ne(a, b)
	var ca: PackedColorArray = a.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var cb: PackedColorArray = b.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_ne(ca[0].to_html(), cb[0].to_html())

func test_every_biome_is_deterministic_and_filled() -> void:
	for biome: String in PlanetGenerator.BIOMES:
		var a := PlanetGenerator.generate(17, biome)
		var b := PlanetGenerator.generate(17, biome)
		assert_eq(a.placements.size(), b.placements.size(), biome)
		assert_gt(a.placements.size(), 250, "%s com pouca decoração" % biome)
		assert_true(a.placements[10].dir.is_equal_approx(b.placements[10].dir), biome)

func test_planet_builds_in_every_biome() -> void:
	for biome: String in PlanetGenerator.BIOMES:
		var p := Planet.new()
		p.culling_enabled = false
		add_child(p)
		p.build(PlanetGenerator.generate(2, biome))
		assert_eq(p.prop_instance_count(), p.data.placements.size(), biome)
		p.free()

func test_kit_props_and_rocks_get_biome_colours() -> void:
	var p := Planet.new()
	p.culling_enabled = false
	add_child(p)
	p.build(PlanetGenerator.generate(2, "lava"))
	var biome: Dictionary = PlanetGenerator.BIOMES["lava"]
	var tints := {}
	for r in p.get_children():
		if not r.name.begins_with("Region"):
			continue
		for mmi: MultiMeshInstance3D in r.get_children():
			if mmi.name.begins_with("Turf"):
				continue
			var m := mmi.material_override as ShaderMaterial
			if not m.get_shader_parameter("use_vertex_color"):
				tints[(m.get_shader_parameter("albedo_tint") as Color).to_html()] = true
	assert_true(tints.has((biome.kit_tint as Color).to_html()), "modelos do kit sem o tom da lava")
	assert_true(tints.has((biome.palette.Rock as Color).to_html()), "rochas sem a cor de rocha da lava")
	p.free()

func test_rocks_come_in_piles() -> void:
	# O grupo de aglomerados junta pedras: muitas têm vizinhas a menos de 3 m.
	var d := PlanetGenerator.generate(5, "prado")
	var small := d.placements.filter(func(q: Dictionary) -> bool: return (q.kind as String).begins_with("rocks/") and q.size < 1.1 and q.clear < 0.5)
	assert_gt(small.size(), 80)
	var close := 0
	for a in small:
		for b in small:
			if a != b and d.arc_m(a.dir, b.dir) < 3.0:
				close += 1
				break
	assert_gt(float(close) / small.size(), 0.6, "as pedras pequenas deviam estar aglomeradas")

func test_dense_turf_everywhere_except_spots() -> void:
	var d := PlanetGenerator.generate(4, "prado")
	var area := 4.0 * PI * d.radius * d.radius
	assert_gt(d.turf_dirs.size(), int(area * 0.7), "relva pouco densa no prado")
	for i in range(0, d.turf_dirs.size(), 37):
		for s in d.flat_spots:
			assert_gt(d.arc_m(d.turf_dirs[i], s.dir), s.angle * d.radius * 0.75, "relva em cima de um posto")
	var again := PlanetGenerator.generate(4, "prado")
	assert_eq(again.turf_dirs.size(), d.turf_dirs.size())
	assert_true(again.turf_dirs[100].is_equal_approx(d.turf_dirs[100]))

func test_turf_is_built_in_regions() -> void:
	var p := Planet.new()
	p.culling_enabled = false
	add_child(p)
	p.build(PlanetGenerator.generate(4, "prado"))
	var n := 0
	for r in p.get_children():
		if r.name.begins_with("Region"):
			for c in r.get_children():
				if c.name.begins_with("Turf"):
					n += (c as MultiMeshInstance3D).multimesh.instance_count
	assert_eq(n, p.data.turf_dirs.size())
	p.free()
