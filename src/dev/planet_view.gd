extends Node3D
## Visualizador de planetas (issue #5): gera um planeta Prado a partir de uma seed e deixa
## orbitar a câmara (arrastar). DBG: nova seed, raio, culling.

const LOOK_SENS := 0.005

var planet: Planet
var seed_value := 1
var radius := PlanetGenerator.DEFAULT_RADIUS
var _cam: Camera3D
var _yaw := 0.4
var _pitch := 0.35
var _dist := 150.0
var _info: Label

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("seed="):
			seed_value = int(a.substr(5))
		if a.begins_with("dist="):
			_dist = float(a.substr(5))
	_build_world()
	planet = Planet.new()
	add_child(planet)
	_build_ui()
	regenerate()
	DebugMenu.add_button(self, "DBG_NEW_SEED", func() -> void:
		seed_value = randi() % 100000
		regenerate())
	DebugMenu.add_slider(self, "DBG_RADIUS", 30.0, 100.0, 5.0, radius, func(v: float) -> void:
		radius = v
		regenerate())
	DebugMenu.add_slider(self, "DBG_ZOOM", 70.0, 260.0, 5.0, _dist, func(v: float) -> void: _dist = v)
	DebugMenu.add_toggle(self, "DBG_CULLING", true, func(on: bool) -> void:
		planet.culling_enabled = on
		if not on:
			for c in planet.get_children():
				if c.name.begins_with("Region"):
					c.visible = true)

func regenerate() -> void:
	var t0 := Time.get_ticks_msec()
	var d := PlanetGenerator.generate(seed_value, "prado", radius)
	var t1 := Time.get_ticks_msec()
	planet.build(d)
	var t2 := Time.get_ticks_msec()
	_info.text = "seed %d · %d objetos · gerar %d ms · construir %d ms" % [seed_value, planet.prop_instance_count(), t1 - t0, t2 - t1]
	print(_info.text)

func _process(delta: float) -> void:
	var look := InputHub.consume_look(delta)
	_yaw -= look.x * LOOK_SENS
	_pitch = clampf(_pitch + look.y * LOOK_SENS, -1.4, 1.4)
	_cam.position = Basis.from_euler(Vector3(-_pitch, _yaw, 0)) * Vector3(0, 0, _dist)
	_cam.look_at(Vector3.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	# No PC e no telemóvel (emulação de rato): arrastar com o botão esquerdo também orbita.
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		InputHub.add_look((event as InputEventMouseMotion).relative)

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("231a38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9a8e8")
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 1000.0
	add_child(_cam)

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var back := Button.new()
	back.text = "UI_BACK"
	back.add_theme_font_size_override("font_size", 26)
	back.position = Vector2(24, 16)
	back.custom_minimum_size = Vector2(160, 64)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/boot.tscn"))
	hud.add_child(back)
	_info = Label.new()
	_info.position = Vector2(24, 92)
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 5)
	hud.add_child(_info)
