extends Node3D
## Protótipo da F1: um planeta gerado, o astronauta, o rover e a câmara.
## (As entregas entram no ticket #8.)

const ENTER_DISTANCE := 5.0
const REPAIR_RADIUS := 16.0 # junto ao posto avançado
const REPAIR_RATE := 20.0 # vida por segundo, parado junto à base
const RESPAWN_DELAY := 2.6
const EXPLOSION := "res://assets/BinbunVFX_Vol2/ExplosionFX/effects/ground/vfx_ground_explosion_01.tscn"
const CAM_FOOT := {"distance": 6.5, "pitch": -0.42, "focus_height": 1.2, "auto_return_delay": 1.6}
const CAM_ROVER := {"distance": 9.5, "pitch": -0.36, "focus_height": 1.6, "auto_return_delay": 0.35}

var seed_value := 1
var biome := "prado"
var planet: Planet
var player: Astronaut
var camera: PlanetCamera
var touch: TouchControls
var sun: DirectionalLight3D
var rover: Rover
var driving := false
var _vehicle_btn := JumpBuffer.new()
var _hint: Label
var wallet := Wallet.new()
var bars: StatusBars
var respawning := false
var deliveries: DeliveryController

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_value = int(a.substr(5))
		if a.begins_with("biome="):
			biome = a.substr(6)
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
	rover.destroyed.connect(_on_rover_destroyed)
	_build_ui()
	deliveries = DeliveryController.new()
	deliveries.name = "Deliveries"
	add_child(deliveries)
	deliveries.setup(self, wallet, _hud_layer)
	bars = StatusBars.new()
	_hud_layer.add_child(bars)
	bars.add_bar("rover", "BAR_ROVER", Color("ff9f5a"))
	rover.health_changed.connect(func(v: float, m: float) -> void: bars.set_value("rover", v, m))
	bars.set_value("rover", rover.health, rover.max_health)
	start(seed_value)
	_register_debug()
	var args := OS.get_cmdline_user_args() # argumentos só para capturas de ecrã no PC
	if "board" in args:
		deliveries.open_board()
	if "order" in args:
		var o: DeliveryOrder = deliveries.session.offers[0]
		deliveries.accept(o)
		deliveries.session.pick_up()
		deliveries.session.tick(12.0)
		_vehicle_btn = JumpBuffer.new()
		enter_rover()
	if "forest" in args:
		spawn_in_forest()
	if "rocks" in args:
		spawn_in_forest("rocks/")
	if "boom" in args:
		enter_rover()
		await get_tree().create_timer(1.0).timeout
		rover.take_damage(999.0)
	if "perf" in args:
		_perf_log()
	if "drive" in args:
		await get_tree().create_timer(0.5).timeout
		enter_rover()
		Input.action_press("move_forward", 1.0)
		Input.action_press("move_right", 0.25)

## Gera o planeta `s` e põe o jogador junto ao posto avançado.
func start(s: int) -> void:
	seed_value = s
	planet.build(PlanetGenerator.generate(s, biome))
	_apply_biome_sky()
	player.planet_center = planet.global_position
	camera.planet_center = planet.global_position
	rover.planet_center = planet.global_position
	if driving:
		exit_rover()
	spawn_near(planet.data.outpost_dir, planet.data.posts[0], 9.0)
	_park_rover_near_player()
	if deliveries:
		deliveries.start_planet(planet.data)

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

## Põe o jogador à beira do sítio com mais árvores (ou objetos cujo tipo começa por `prefix`).
## Para capturas de ecrã.
func spawn_in_forest(prefix := "") -> void:
	var trees := planet.data.placements.filter(func(p: Dictionary) -> bool:
		return (p.kind as String).begins_with(prefix) if prefix != "" else p.size > 2.8)
	var best: Vector3 = trees[0].dir
	var best_n := 0
	for t in trees.slice(0, 120):
		var n := 0
		for o in trees:
			if planet.data.arc_m(t.dir, o.dir) < 14.0:
				n += 1
		if n > best_n:
			best_n = n
			best = t.dir
	spawn_near(best, planet.data.outpost_dir, 9.0)

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

## Explosão do rover: efeito, a encomenda falha e, passado um pouco, renasces na base
## com o rover reparado.
func _on_rover_destroyed() -> void:
	respawning = true
	spawn_explosion(rover.global_position, rover.planet_up())
	rover.visible = false
	rover.freeze = true
	if deliveries.session and deliveries.session.fail_active():
		deliveries.hud.toast(tr("TOAST_ORDER_LOST"))
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if not is_inside_tree():
		return
	if driving:
		driving = false
		rover.driven = false
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.visible = true
		player.controllable = true
		player.collision_layer = 2
	spawn_near(planet.data.outpost_dir, planet.data.posts[0], 9.0)
	rover.restore()
	_park_rover_near_player()
	respawning = false

func spawn_explosion(pos: Vector3, up: Vector3) -> Node3D:
	var fx: Node3D = (load(EXPLOSION) as PackedScene).instantiate()
	add_child(fx)
	fx.global_transform = Transform3D(SphereMath.basis_from_up(up).scaled(Vector3.ONE * 2.2), pos)
	if fx.has_method("play"):
		fx.call("play")
	get_tree().create_timer(5.0).timeout.connect(fx.queue_free)
	return fx

func rover_near_base() -> bool:
	return rover.global_position.distance_to(planet.to_global(planet.data.surface_point(planet.data.outpost_dir))) < REPAIR_RADIUS

func _physics_process(delta: float) -> void:
	if rover.alive and rover.health < rover.max_health and rover_near_base() and rover.linear_velocity.length() < 1.0:
		rover.repair(REPAIR_RATE * delta)
	bars.show_bar("rover", driving or rover.health < rover.max_health)
	if respawning:
		_hint.text = ""
		return
	_vehicle_btn.update(Input.is_action_pressed("vehicle"), delta)
	if _vehicle_btn.consume() and not deliveries.board_open:
		if driving:
			exit_rover()
		elif can_enter_rover():
			enter_rover()
	if driving:
		var m := InputHub.move_vector()
		rover.throttle = m.y
		rover.steer = m.x
	var h := tr("HINT_EXIT_ROVER") if driving else (tr("HINT_ENTER_ROVER") if can_enter_rover() else "")
	var dh := deliveries.hint()
	_hint.text = "" if deliveries.board_open else (dh if dh != "" and not driving else (h if h != "" else dh))

var _env: Environment

## Céu e luz ambiente de cada bioma.
func _apply_biome_sky() -> void:
	var sky: Dictionary = PlanetGenerator.BIOMES[biome].get("sky", {})
	_env.background_color = sky.get("bg", Color("2b2146"))
	_env.ambient_light_color = sky.get("ambient", Color("b9a8e8"))
	sun.light_color = sky.get("sun", Color("fff1dc"))

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
	_env = env
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

var _hud_layer: CanvasLayer

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	_hud_layer = hud
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

## Mede draw calls e triângulos durante uns segundos (capturas no PC).
func _perf_log() -> void:
	for i in 6:
		await get_tree().create_timer(1.0).timeout
		print("perf ", "condução " if driving else "a pé ", DebugMenu.stats_text())

func _update_touch_visibility() -> void:
	if is_instance_valid(touch):
		touch.visible = DisplayServer.is_touchscreen_available() or DebugMenu.force_touch

func _register_debug() -> void:
	DebugMenu.add_label(self, func() -> String: return "%s · seed %d · %d ¢" % [biome, seed_value, wallet.credits()])
	DebugMenu.add_button(self, "DBG_NEW_SEED", func() -> void: start(randi() % 100000))
	DebugMenu.add_button(self, "DBG_NEXT_BIOME", func() -> void:
		var names := PlanetGenerator.BIOMES.keys()
		biome = names[(names.find(biome) + 1) % names.size()]
		start(seed_value))
	DebugMenu.add_button(self, "DBG_GOTO_OUTPOST", func() -> void:
		spawn_near(planet.data.outpost_dir, planet.data.posts[0], 9.0))
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
	DebugMenu.add_button(self, "DBG_ADD_CREDITS", func() -> void: wallet.add(Wallet.CREDITS, 500))
	DebugMenu.add_button(self, "DBG_ROVER_DAMAGE", func() -> void: rover.take_damage(40.0))
	DebugMenu.add_slider(self, "DBG_ROVER_BOUNCE", 80.0, 600.0, 10.0, rover.spring_damp, func(v: float) -> void: rover.spring_damp = v)
	DebugMenu.add_slider(self, "DBG_ROVER_SPIN", 0.0, 4.0, 0.1, rover.spin_damp, func(v: float) -> void: rover.spin_damp = v)
	DebugMenu.add_slider(self, "DBG_ROVER_AIR", 0.0, 8.0, 0.2, rover.air_align, func(v: float) -> void: rover.air_align = v)
	DebugMenu.add_button(self, "DBG_ROVER_HERE", func() -> void:
		if driving:
			exit_rover()
		_park_rover_near_player())
