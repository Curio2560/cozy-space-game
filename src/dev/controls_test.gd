extends Node3D
## Cena de teste dos controlos (issue #4): um cubo num chão plano que anda com o joystick
## (relativo à câmara), salta, e uma câmara que roda ao arrastar o lado direito do ecrã.

const LOOK_SENS := 0.005 # radianos por píxel de arrasto

@export var speed := 6.0
@export var jump_velocity := 7.0
@export var gravity := 20.0

var player: CharacterBody3D
var touch: TouchControls
var _cam: Camera3D
var _yaw := 0.0
var _pitch := -0.35
var _jump := JumpBuffer.new()

func _ready() -> void:
	_build_world()
	_build_player()
	_build_ui()
	DebugMenu.add_slider(self, "DBG_SPEED", 1.0, 15.0, 0.5, speed, func(v: float) -> void: speed = v)
	DebugMenu.add_slider(self, "DBG_JUMP", 2.0, 15.0, 0.5, jump_velocity, func(v: float) -> void: jump_velocity = v)
	DebugMenu.add_button(self, "DBG_RESET", reset_player)
	# Capturas de ecrã no PC: `-- touch` mostra os controlos táteis, `-- dbg` abre o menu.
	var args := OS.get_cmdline_user_args()
	if "touch" in args:
		DebugMenu.force_touch = true
		_update_touch_visibility()
	if "dbg" in args and not DebugMenu.is_open():
		DebugMenu.toggle()

func reset_player() -> void:
	player.position = Vector3(0, 1, 0)
	player.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	var look := InputHub.consume_look(delta)
	_yaw -= look.x * LOOK_SENS
	_pitch = clampf(_pitch - look.y * LOOK_SENS, -1.2, -0.05)

	var input := InputHub.move_vector()
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var dir := right * input.x + fwd * input.y
	player.velocity.x = dir.x * speed
	player.velocity.z = dir.z * speed
	_jump.update(Input.is_action_pressed("jump"), delta)
	if player.is_on_floor():
		if _jump.consume():
			player.velocity.y = jump_velocity
	else:
		player.velocity.y -= gravity * delta
	player.move_and_slide()
	if dir.length() > 0.05:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)

	var offset := Basis.from_euler(Vector3(_pitch, _yaw, 0)) * Vector3(0, 0, 8.0)
	_cam.position = player.position + Vector3(0, 1.0, 0) + offset
	_cam.look_at(player.position + Vector3(0, 0.8, 0))

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2146")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9a8e8")
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(60, 1, 60)
	shape.position.y = -0.5
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = Vector3(60, 1, 60)
	mesh.position.y = -0.5
	mesh.material_override = CelShading.terrain(Color("8fd3a0"))
	ground.add_child(mesh)
	add_child(ground)
	# Referências visuais para se perceber o movimento.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 14:
		var path: String = ["natureza/Tree_Blob_1.gltf", "natureza/Rock_Large_2.gltf", "natureza/Bush_2.gltf"][i % 3]
		var m: Node3D = (load("res://assets/kit/" + path) as PackedScene).instantiate()
		add_child(m)
		m.position = Vector3(rng.randf_range(-22, 22), 0, rng.randf_range(-22, 22))
		KitUtil.fit_height(m, [3.2, 1.2, 0.8][i % 3])
		CelShading.apply(m)

func _build_player() -> void:
	player = CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.position.y = 0.5
	player.add_child(shape)
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.position.y = 0.5
	body.material_override = CelShading.flat(Color("ff9f7a"))
	player.add_child(body)
	var nose := MeshInstance3D.new() # mostra para onde o cubo está virado
	nose.mesh = BoxMesh.new()
	(nose.mesh as BoxMesh).size = Vector3(0.3, 0.3, 0.3)
	nose.position = Vector3(0, 0.7, -0.6)
	nose.material_override = CelShading.flat(Color("ffc857"))
	player.add_child(nose)
	add_child(player)
	reset_player()
	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	touch = TouchControls.new()
	hud.add_child(touch)
	_update_touch_visibility()
	DebugMenu.force_touch_changed.connect(func(_on: bool) -> void: _update_touch_visibility())
	var back := Button.new()
	back.text = "UI_BACK"
	back.add_theme_font_size_override("font_size", 26)
	back.position = Vector2(24, 16)
	back.custom_minimum_size = Vector2(160, 64)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/boot.tscn"))
	hud.add_child(back)

func _update_touch_visibility() -> void:
	if is_instance_valid(touch):
		touch.visible = DisplayServer.is_touchscreen_available() or DebugMenu.force_touch
