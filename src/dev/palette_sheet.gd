extends Node3D
## Folha de comparação: os mesmos modelos do pack de natureza nas paletas de cada bioma.
## Uma fila por bioma. Só para capturas de ecrã/aprovação do look.

const MODELS := ["nature/BirchTree_1", "nature/CommonTree_Autumn_4", "nature/CommonTree_Dead_2", "nature/BushBerries_1", "nature/Bush_2", "nature/Cactus_3", "nature/CactusFlowers_2"]

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("231a38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4bce0")
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var biomes := PlanetGenerator.BIOMES.keys()
	for row in biomes.size():
		var b: String = biomes[row]
		var z := -row * 7.0
		var ground := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(MODELS.size() * 4.0 + 2.0, 0.3, 5.0)
		ground.mesh = box
		ground.position = Vector3((MODELS.size() - 1) * 2.0, -0.15, z)
		ground.material_override = CelShading.terrain(PlanetGenerator.BIOMES[b].ground)
		add_child(ground)
		for i in MODELS.size():
			var info := KitUtil.single_mesh(MODELS[i])
			var mi := MeshInstance3D.new()
			mi.mesh = CelShading.palette_mesh(info.mesh, PlanetGenerator.BIOMES[b].palette)
			mi.material_override = CelShading.vertex_color_material(true)
			var h: float = (info.aabb as AABB).size.y
			var target := 3.6 if MODELS[i].contains("Tree") else 1.6
			mi.scale = Vector3.ONE * (target / h)
			mi.position = Vector3(i * 4.0, 0, z)
			mi.rotation.y = 0.6
			add_child(mi)
		var label := Label3D.new()
		label.text = b
		label.font_size = 120
		label.pixel_size = 0.01
		label.outline_size = 24
		label.position = Vector3(-3.2, 1.0, z)
		add_child(label)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.position = Vector3((MODELS.size() - 1) * 2.0, 15.0, 15.0)
	cam.look_at(Vector3((MODELS.size() - 1) * 2.0, 0.5, -7.0))
