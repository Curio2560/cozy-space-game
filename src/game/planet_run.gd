extends Node3D
## Protótipo da F1: um planeta gerado, o astronauta e a câmara.
## (O rover e as entregas entram nos tickets #7 e #8.)

var seed_value := 1
var planet: Planet
var player: Astronaut
var camera: PlanetCamera
var touch: TouchControls
var sun: DirectionalLight3D

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
	camera.target_facing = func() -> Vector3: return player.facing
	_build_ui()
	start(seed_value)
	_register_debug()

## Gera o planeta `s` e põe o jogador junto ao posto avançado.
func start(s: int) -> void:
	seed_value = s
	planet.build(PlanetGenerator.generate(s))
	player.planet_center = planet.global_position
	camera.planet_center = planet.global_position
	spawn_near(planet.data.outpost_dir, planet.data.posts[0], 9.0)

## Coloca o jogador a `arc_m` metros de `dir`, na direção de `toward`.
func spawn_near(dir: Vector3, toward: Vector3, arc_m: float) -> void:
	var d := planet.data
	var axis := dir.cross(toward).normalized()
	var spot := dir.rotated(axis, arc_m / d.radius) if axis.length() > 0.1 else dir
	teleport(spot)

func teleport(dir: Vector3) -> void:
	var p := planet.to_global(planet.data.surface_point(dir) + dir * 0.6)
	player.place_at(p)
	camera.set_target(player, player.facing)

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
	var u := player.up()
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
