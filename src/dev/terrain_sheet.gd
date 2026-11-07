extends Node3D
func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("231a38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4bce0")
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -35, 0); add_child(sun)
	var files := Array(DirAccess.get_files_at("res://assets/terrain")).filter(func(f): return f.ends_with(".obj"))
	files.sort()
	for i in files.size():
		var m: Mesh = load("res://assets/terrain/" + files[i])
		var mi := MeshInstance3D.new(); mi.mesh = m
		var s := 8.0 / maxf(m.get_aabb().size.x, m.get_aabb().size.z)
		mi.scale = Vector3.ONE * s
		mi.material_override = CelShading.material_for(m.surface_get_material(0), false)
		mi.position = Vector3((i % 7) * 10.0, 0, (i / 7) * 10.0)
		add_child(mi)
		var l := Label3D.new(); l.text = files[i].get_basename().replace("SM_", ""); l.font_size = 64; l.pixel_size = 0.02; l.outline_size = 16
		l.position = mi.position + Vector3(0, 6, 4); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; add_child(l)
	var cam := Camera3D.new(); cam.fov = 45; add_child(cam)
	cam.position = Vector3(30, 55, 62); cam.look_at(Vector3(30, 0, 20))
