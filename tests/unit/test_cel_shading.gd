extends GutTest

const ASTRONAUT := "res://assets/kit/personagens/Astronaut_FinnTheFrog.gltf"
const TREE := "res://assets/kit/natureza/Tree_Blob_1.gltf"
const CRATE := "res://assets/kit/pickups/Pickup_Crate.gltf"

func before_each() -> void:
	CelShading.clear_cache()

func _load(path: String) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	add_child_autofree(n)
	return n

func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

func test_apply_gives_every_surface_cel_material_with_outline_pass() -> void:
	var model := _load(ASTRONAUT)
	var changed := CelShading.apply(model)
	assert_gt(changed, 0)
	for mi in _meshes(model):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as ShaderMaterial
			assert_not_null(m, "superfície sem ShaderMaterial em %s" % mi.name)
			assert_eq(m.shader, CelShading.CEL_SHADER)
			assert_not_null(m.next_pass, "falta o passe de contorno")
			assert_eq((m.next_pass as ShaderMaterial).shader, CelShading.OUTLINE_SHADER)

func test_apply_keeps_the_palette_texture() -> void:
	var model := _load(TREE)
	CelShading.apply(model)
	var m := _meshes(model)[0].get_active_material(0) as ShaderMaterial
	assert_not_null(m.get_shader_parameter("albedo_tex"), "o material perdeu a paleta do kit")

func test_models_with_same_palette_share_one_material() -> void:
	var a := _load(TREE)
	var b := _load(TREE)
	CelShading.apply(a)
	CelShading.apply(b)
	assert_eq(_meshes(a)[0].get_active_material(0), _meshes(b)[0].get_active_material(0))
	assert_eq(CelShading.cached_material_count(), 1)

func test_whole_kit_needs_only_a_handful_of_materials() -> void:
	for p in [ASTRONAUT, TREE, CRATE, "res://assets/kit/veiculos/Rover_1.gltf", "res://assets/kit/natureza/Rock_1.gltf"]:
		CelShading.apply(_load(p))
	assert_lte(CelShading.cached_material_count(), 5)

func test_outline_mesh_is_shared_and_keeps_vertices_and_bones() -> void:
	var model := _load(ASTRONAUT)
	var skinned := _meshes(model).filter(func(m: MeshInstance3D) -> bool: return m.skin != null)
	assert_eq(skinned.size(), 1, "o astronauta devia ter uma malha animada (o corpo)")
	var mi: MeshInstance3D = skinned[0]
	var original := mi.mesh as ArrayMesh
	var prepared := CelShading.outline_ready_mesh(original) as ArrayMesh
	assert_eq(CelShading.outline_ready_mesh(original), prepared, "a malha preparada devia vir da cache")
	assert_eq(CelShading.outline_ready_mesh(prepared), prepared, "preparar duas vezes não deve copiar de novo")
	var a := original.surface_get_arrays(0)
	var b := prepared.surface_get_arrays(0)
	assert_eq((b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	assert_not_null(b[Mesh.ARRAY_BONES], "perdeu os ossos (personagem animada)")
	assert_not_null(b[Mesh.ARRAY_WEIGHTS], "perdeu os pesos (personagem animada)")

func test_vertices_at_same_position_get_same_unit_outline_normal() -> void:
	# Num cubo cada canto tem 3 vértices com normais diferentes: o contorno tem de os mover juntos.
	var box := ArrayMesh.new()
	box.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().get_mesh_arrays())
	var arrays := (CelShading.outline_ready_mesh(box) as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var tan: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var by_pos := {}
	for v in verts.size():
		var n := Vector3(tan[v * 4], tan[v * 4 + 1], tan[v * 4 + 2])
		assert_almost_eq(n.length(), 1.0, 0.01)
		var k := Vector3i((verts[v] * 1000.0).round())
		if by_pos.has(k):
			assert_true((by_pos[k] as Vector3).is_equal_approx(n), "normais diferentes no mesmo canto")
		else:
			by_pos[k] = n
	assert_eq(by_pos.size(), 8, "um cubo tem 8 cantos")
