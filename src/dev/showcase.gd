extends Node3D
## Vitrine do kit com cel-shading, para aprovar o look (issue #3).
## Argumentos opcionais depois de `--`: `plain` mostra os materiais originais (comparação);
## `close` usa uma câmara de perto.

const KIT := "res://assets/kit/"
## [ficheiro, posição x, posição z, altura alvo em metros, animação]
const ITEMS := [
	["personagens/Astronaut_FinnTheFrog.gltf", -2.2, 1.2, 1.7, "Idle"],
	["personagens/Astronaut_BarbaraTheBee.gltf", -0.9, 1.8, 1.7, "Wave"],
	["veiculos/Rover_1.gltf", 1.4, 0.6, 1.6, ""],
	["mechs/Mech_RaeTheRedPanda.gltf", 3.6, -0.4, 2.8, "Idle"],
	["inimigos/Enemy_Small.gltf", 3.2, 2.2, 1.1, "Idle"],
	["naves/Spaceship_FernandoTheFlamingo.gltf", 2.0, -5.5, 2.2, ""],
	["natureza/Tree_Blob_1.gltf", -4.6, -2.0, 3.6, ""],
	["natureza/Tree_Lava_1.gltf", 5.6, -3.2, 3.4, ""],
	["natureza/Tree_Spikes_1.gltf", -3.4, -4.2, 3.0, ""],
	["natureza/Bush_1.gltf", -4.0, 2.2, 0.8, ""],
	["natureza/Rock_Large_1.gltf", 5.4, 1.6, 1.3, ""],
	["pickups/Pickup_Crate.gltf", 0.2, 3.2, 0.6, ""],
	["pickups/Pickup_Sphere.gltf", 1.6, 3.4, 0.6, ""],
	["base/House_Cylinder.gltf", -1.8, -4.6, 3.0, ""],
]

@export var spin_speed := 0.35
var _spinners: Array[Node3D] = []

func _ready() -> void:
	var plain := "plain" in OS.get_cmdline_user_args()
	_build_world()
	_build_hud()
	var ground := _make_ground()
	add_child(ground)
	for it in ITEMS:
		var scene: PackedScene = load(KIT + it[0])
		var model: Node3D = scene.instantiate()
		model.position = Vector3(it[1], 0.0, it[2])
		add_child(model)
		KitUtil.fit_height(model, it[3])
		if not plain:
			CelShading.apply(model)
		if it[4] != "":
			_play(model, it[4])
		_spinners.append(model)

func _process(delta: float) -> void:
	for s in _spinners:
		s.rotate_y(spin_speed * delta)

## Botão para voltar (os FPS estão no menu DBG).
func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var back := Button.new()
	back.text = "UI_BACK"
	back.add_theme_font_size_override("font_size", 26)
	back.position = Vector2(24, 16)
	back.custom_minimum_size = Vector2(160, 64)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/boot.tscn"))
	hud.add_child(back)

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2146")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9a8e8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 25.0
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	if "close" in OS.get_cmdline_user_args():
		cam.position = Vector3(-0.6, 1.9, 5.2)
		cam.look_at(Vector3(0.0, 1.0, 1.0))
	else:
		cam.position = Vector3(0, 5.0, 12.5)
		cam.look_at(Vector3(0.4, 1.0, -0.6))

func _make_ground() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 8.0
	cyl.bottom_radius = 8.0
	cyl.height = 0.2
	cyl.radial_segments = 48
	mi.mesh = cyl
	mi.position.y = -0.1
	mi.material_override = CelShading.terrain(Color("8fd3a0"))
	return mi

func _play(model: Node, anim: String) -> void:
	var ap := _find_anim(model)
	if ap == null:
		return
	for a in [anim, "Idle"]:
		if ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
			ap.play(a)
			return

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null
