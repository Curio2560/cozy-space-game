extends GutTest

func test_fit_height_scales_model_to_target_and_rests_on_ground() -> void:
	for path in ["res://assets/kit/natureza/Rock_Large_1.gltf", "res://assets/kit/personagens/Astronaut_RaeTheRedPanda.gltf"]:
		var holder := Node3D.new()
		add_child_autofree(holder)
		var m: Node3D = (load(path) as PackedScene).instantiate()
		holder.add_child(m)
		KitUtil.fit_height(m, 1.7)
		var box: AABB = KitUtil.local_aabb(holder)
		assert_almost_eq(box.size.y, 1.7, 0.01, path)
		assert_almost_eq(box.position.y, 0.0, 0.01, path)
