extends GutTest
## Catálogo de criaturas: todas carregam em cel-shading; as animadas têm as animações
## de que o jogo precisa; o tom muda com o bioma.

const ROLES := ["idle", "move", "run", "attack", "hit", "death"]
## Exceções conhecidas do pack: o Demon voador só traz Flying_Idle.
const FEW_ANIMS := ["flying/Demon"]

func test_every_creature_instantiates_with_cel_shading() -> void:
	for id in CreatureCatalog.ids():
		var c := CreatureCatalog.instantiate(id)
		add_child_autofree(c)
		var meshes := c.find_children("*", "MeshInstance3D", true, false)
		assert_gt(meshes.size(), 0, "%s sem malha" % id)
		var m := (meshes[0] as MeshInstance3D).get_active_material(0) as ShaderMaterial
		assert_not_null(m, "%s sem material cel" % id)
		var box := KitUtil.local_aabb(c)
		assert_almost_eq(box.size.y, CreatureCatalog.height(id), 0.05, id)
		assert_almost_eq(box.position.y, CreatureCatalog.hover(id), 0.05, "%s: pés no chão (ou a pairar)" % id)

func test_fifty_creatures_in_three_families() -> void:
	var ids := CreatureCatalog.ids()
	assert_eq(ids.size(), 50)
	for fam in ["big", "blob", "flying"]:
		assert_gt(ids.filter(func(i: String) -> bool: return i.begins_with(fam + "/")).size(), 10, fam)

func test_every_creature_has_an_animation_for_every_role() -> void:
	for id in CreatureCatalog.ids():
		var c := CreatureCatalog.instantiate(id)
		add_child_autofree(c)
		var ap := CreatureCatalog.animation_player(c)
		assert_not_null(ap, id)
		var fam: Dictionary = CreatureCatalog.FAMILIES[CreatureCatalog.family(id)].anims
		for role in ROLES:
			var n := CreatureCatalog.anim(c, role)
			assert_ne(n, "", "%s sem animação para %s" % [id, role])
			if id not in FEW_ANIMS:
				assert_eq(n, fam[role], "%s: %s devia ser %s" % [id, role, fam[role]])
		assert_true(ap.is_playing(), "%s devia começar a animar" % id)

func test_creature_colour_follows_biome() -> void:
	var a := CreatureCatalog.instantiate("big/Dino", "prado")
	var b := CreatureCatalog.instantiate("big/Dino", "lava")
	add_child_autofree(a)
	add_child_autofree(b)
	var ma := (a.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_active_material(0) as ShaderMaterial
	var mb := (b.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_active_material(0) as ShaderMaterial
	assert_ne((ma.get_shader_parameter("albedo_tint") as Color).to_html(), (mb.get_shader_parameter("albedo_tint") as Color).to_html())

func test_catalog_finds_models_in_exported_builds_too() -> void:
	# No APK a pasta lista "X.gltf.import"/".remap" em vez de "X.gltf".
	var exported := PackedStringArray(["Alien.gltf.import", "Birb.gltf.remap", "Atlas.png.import", "Dino.gltf.import", "Dino.gltf.remap"])
	assert_eq(CreatureCatalog.gltf_names(exported), ["Alien", "Birb", "Dino"])
	var editor := PackedStringArray(["Alien.gltf", "Alien.gltf.import", "Birb.gltf"])
	assert_eq(CreatureCatalog.gltf_names(editor), ["Alien", "Birb"])
