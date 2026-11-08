extends Node3D
## Vitrine dos edifícios montados com o pack modular (casa do colono e base).
func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("231a38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4bce0")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(60, 40)
	ground.material_override = CelShading.terrain(Color("8fd3a0"))
	add_child(ground)
	var h := BuildingKit.build(BuildingKit.colonist_house(), BuildingKit.palette_with_accent(BuildingKit.COLONIST_ACCENTS[0]), false)
	h.position = Vector3(-9, 0, 0)
	add_child(h)
	var h2 := BuildingKit.build(BuildingKit.colonist_house(), BuildingKit.palette_with_accent(BuildingKit.COLONIST_ACCENTS[1]), false)
	h2.position = Vector3(-9, 0, 9)
	add_child(h2)
	var o := BuildingKit.build(BuildingKit.outpost(), BuildingKit.BASE_PALETTE, false)
	o.position = Vector3(6, 0, 2)
	add_child(o)
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	var back := "back" in OS.get_cmdline_user_args()
	cam.position = Vector3(-2, 14, -22) if back else Vector3(-2, 14, 26)
	cam.look_at(Vector3(-1, 2, 3))
