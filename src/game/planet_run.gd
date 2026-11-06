extends Node3D
## Protótipo da F1: um planeta gerado, o astronauta, o rover e a câmara.
## (As entregas entram no ticket #8.)

const ENTER_DISTANCE := 5.0
const CAM_FOOT := {"distance": 6.5, "pitch": -0.42, "focus_height": 1.2, "auto_return_delay": 1.6}
const CAM_ROVER := {"distance": 9.5, "pitch": -0.36, "focus_height": 1.6, "auto_return_delay": 0.35}

var seed_value := 1
var planet: Planet
var player: Astronaut
var camera: PlanetCamera
var touch: TouchControls
var sun: DirectionalLight3D
var rover: Rover
var driving := false
var _vehicle_btn := JumpBuffer.new()
var _hint: Label

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_value = int(a.substr(5))
	_build_world()
	planet = Planet.new()
	planet.name = "Planet"
	add_child(planet)
	player = Astronaut.new()
	player.name = "Player"
	add_child(player)
	camera = PlanetCamera.new()
	camera.name = "Camera"
	camera.fov = 62.0
	camera.far = 600.0
	add_child(camera)
	player.view = camera
	player.collision_layer = 2
	player.collision_mask = 1 | 4
	rover = Rover.new()
	rover.name = "Rover"
	rover.collision_layer = 4
	rover.collision_mask = 1 | 2
	add_child(rover)
	_build_ui()
	start(seed_value)
	_register_debug()
	if "drive" in OS.get_cmdline_user_args(): # só para capturas de ecrã no PC
		await get_tree().create_timer(0.5).timeout
		enter_rover()
		Input.action_press("move_forward", 1.0)
		Input.action_press("move_right", 0.25)

## Gera o planeta `s` e põe o jogador junto ao posto avançado.
func start(s: int) -> void:
	seed_value = s
	planet.build(PlanetGenerator.generate(s))
	player.planet_center = planet.global_position
	camera.planet_center = planet.global_position
	rover.planet_center = planet.global_position
	if driving:
		exit_rover()
	spawn_near(planet.data.outpost_dir, planet.data.posts[0], 9.0)
	_park_rover_near_player()

## Coloca o jogador a `arc_m` metros de `dir`, na direção de `toward`.
func spawn_near(dir: Vector3, toward: Vector3, arc_m: float) -> void:
	var d := planet.data
	var axis := dir.cross(toward).normalized()
	var spot := dir.rotated(axis, arc_m / d.radius) if axis.length() > 0.1 else dir
	teleport(spot)

func teleport(dir: Vector3) -> void:
	if driving:
		var p := planet.to_global(planet.data.surface_point(dir) + dir * 1.2)
		rover.place_at(p, rover.forward())
		camera.set_target(rover, rover.forward())
		_apply_camera(CAM_ROVER)
		camera.target_facing = rover.forward
		return
	var p := planet.to_global(planet.data.surface_point(dir) + dir * 0.6)
	player.place_at(p)
	camera.set_target(player, player.facing)
	_apply_camera(CAM_FOOT)
	camera.target_facing = func() -> Vector3: return player.facing

## Estaciona o rover a uns metros do jogador.
func _park_rover_near_player() -> void:
	var u := player.up()
	var side := player.facing.cross(u).normalized()
	var local_dir := planet.to_local(player.global_position + side * 4.5).normalized()
	var p := planet.to_global(planet.data.surface_point(local_dir) + local_dir * 0.9)
	rover.place_at(p, player.facing)

func can_enter_rover() -> bool:
	return not driving and player.global_position.distance_to(rover.global_position) < ENTER_DISTANCE

func enter_rover() -> void:
	driving = true
	rover.driven = true
	player.controllable = false
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.collision_layer = 0
	camera.set_target(rover, rover.forward())
	camera.add_exclude(player.get_rid())
	_apply_camera(CAM_ROVER)
	camera.target_facing = rover.forward

func exit_rover() -> void:
	driving = false
	rover.driven = false
	rover.throttle = 0.0
	rover.steer = 0.0
	var u := rover.planet_up()
	var side := rover.global_basis.x.normalized()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.controllable = true
	player.collision_layer = 2
	player.place_at(rover.global_position + side * 2.2 + u * 0.8)
	player.facing = rover.forward()
	camera.set_target(player, player.facing)
	camera.add_exclude(rover.get_rid())
	_apply_camera(CAM_FOOT)
	camera.target_facing = func() -> Vector3: return player.facing

func _apply_camera(profile: Dictionary) -> void:
	for k: String in profile:
		camera.set(k, profile[k])

func _physics_process(delta: float) -> void:
	_vehicle_btn.update(Input.is_action_pressed("vehicle"), delta)
	if _vehicle_btn.consume():
		if driving:
			exit_rover()
		elif can_enter_rover():
			enter_rover()
	if driving:
		var m := InputHub.move_vector()
		rover.throttle = m.y
		rover.steer = m.x
	_hint.text = tr("HINT_EXIT_ROVER") if driving else (tr("HINT_ENTER_ROVER") if can_enter_rover() else "")

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
	sun = DirectionalLight3D.new()
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	add_child(sun)

## Até existir o ciclo dia/noite (F4) o sol acompanha o jogador: é sempre de dia onde ele está.
func _process(_delta: float) -> void:
	var u := rover.planet_up() if driving else player.up()
	var side := SphereMath.basis_from_up(u).x
	var light_dir := -(u * 0.75 + side * 0.45 + camera.global_basis.z * 0.25).normalized()
	sun.look_at_from_position(Vector3.ZERO, light_dir, u if absf(light_dir.dot(u)) < 0.99 else side)

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	touch = TouchControls.new()
	hud.add_child(touch)
	_update_touch_visibility()
	DebugMenu.force_touch_changed.connect(func(_on: bool) -> void: _update_touch_visibility())
	if "touch" in OS.get_cmdline_user_args():
		DebugMenu.force_touch = true
		_update_touch_visibility()
	var back := Button.new()
	back.text = "UI_BACK"
	back.add_theme_font_size_override("font_size", 26)
	back.position = Vector2(24, 16)
	back.custom_minimum_size = Vector2(160, 64)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/boot.tscn"))
	hud.add_child(back)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y = 24
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_outline_color", Color(0.14, 0.1, 0.22))
	_hint.add_theme_constant_override("outline_size", 8)
	hud.add_child(_hint)

func _update_touch_visibility() -> void:
	if is_instance_valid(touch):
		touch.visible = DisplayServer.is_touchscreen_available() or DebugMenu.force_touch

func _register_debug() -> void:
	DebugMenu.add_button(self, "DBG_NEW_SEED", func() -> void: start(randi() % 100000))
	for i in 3:
		DebugMenu.add_button(self, tr("DBG_GOTO_POST") + " %d" % (i + 1), func() -> void:
			spawn_near(planet.data.posts[i], planet.data.outpost_dir, 7.0))
	DebugMenu.add_slider(self, "DBG_SPEED", 2.0, 16.0, 0.5, player.walk_speed, func(v: float) -> void: player.walk_speed = v)
	DebugMenu.add_slider(self, "DBG_JUMP", 3.0, 16.0, 0.5, player.jump_velocity, func(v: float) -> void: player.jump_velocity = v)
	DebugMenu.add_slider(self, "DBG_GRAVITY", 5.0, 40.0, 1.0, player.gravity, func(v: float) -> void: player.gravity = v)
	DebugMenu.add_slider(self, "DBG_CAM_DIST", 3.0, 14.0, 0.5, camera.distance, func(v: float) -> void: camera.distance = v)
	DebugMenu.add_slider(self, "DBG_ROVER_SPEED", 6.0, 30.0, 1.0, rover.max_speed, func(v: float) -> void: rover.max_speed = v)
	DebugMenu.add_slider(self, "DBG_ROVER_TURN", 0.8, 4.0, 0.1, rover.turn_rate, func(v: float) -> void: rover.turn_rate = v)
	DebugMenu.add_slider(self, "DBG_ROVER_SPRING", 2000.0, 9000.0, 100.0, rover.spring_k, func(v: float) -> void: rover.spring_k = v)
	DebugMenu.add_button(self, "DBG_ROVER_HERE", func() -> void:
		if driving:
			exit_rover()
		_park_rover_near_player())
