extends GutTest
## Catálogo de criaturas: todas carregam em cel-shading; as animadas têm as animações
## de que o jogo precisa; o tom muda com o bioma.

const NEEDED := ["Idle", "Walk", "Run", "Punch", "HitReact", "Death"]

func test_every_creature_instantiates_with_cel_shading() -> void:
	for id in CreatureCatalog.ids():
		var c := CreatureCatalog.instantiate(id)
		add_child_autofree(c)
		var meshes := c.find_children("*", "MeshInstance3D", true, false)
		if c.get_child(0) is MeshInstance3D:
			meshes.append(c.get_child(0))
		assert_gt(meshes.size(), 0, "%s sem malha" % id)
		var m := (meshes[0] as MeshInstance3D).get_active_material(0) as ShaderMaterial
		assert_not_null(m, "%s sem material cel" % id)
		var box := KitUtil.local_aabb(c)
		assert_almost_eq(box.size.y, float(CreatureCatalog.CREATURES[id].height), 0.05, id)

func test_animated_creatures_have_the_animations_the_game_needs() -> void:
	for id in CreatureCatalog.ids():
		if not CreatureCatalog.CREATURES[id].animated:
			continue
		var c := CreatureCatalog.instantiate(id)
		add_child_autofree(c)
		var ap := CreatureCatalog.animation_player(c)
		assert_not_null(ap, id)
		for a in NEEDED:
			assert_true(ap.has_animation(a), "%s sem a animação %s" % [id, a])
		assert_eq(ap.current_animation, "Idle", "%s devia começar em Idle" % id)

func test_creature_colour_follows_biome() -> void:
	var a := CreatureCatalog.instantiate("Dino", "prado")
	var b := CreatureCatalog.instantiate("Dino", "lava")
	add_child_autofree(a)
	add_child_autofree(b)
	var ma := (a.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_active_material(0) as ShaderMaterial
	var mb := (b.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_active_material(0) as ShaderMaterial
	assert_ne((ma.get_shader_parameter("albedo_tint") as Color).to_html(), (mb.get_shader_parameter("albedo_tint") as Color).to_html())
