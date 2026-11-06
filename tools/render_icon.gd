extends SceneTree
## Renderiza o primeiro plano do ícone (astronauta + caixa, cel-shaded, fundo transparente).
## Uso: DISPLAY=:0 godot --path . --rendering-driver opengl3 -s tools/render_icon.gd -- <saida.png> <tamanho>

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var size := int(args[1]) if args.size() > 1 else 1024
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9b8f0")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.2
	vp.add_child(sun)

	var astro: Node3D = load("res://assets/kit/personagens/Astronaut_FinnTheFrog.gltf").instantiate()
	vp.add_child(astro)
	KitUtil.fit_height(astro, 1.7)
	astro.rotation_degrees.y = 6
	for n in astro.find_children("Pistol*", "MeshInstance3D", true, false):
		(n as Node3D).visible = false
	CelShading.apply(astro)
	_pose(astro, "Wave")
	var crate: Node3D = load("res://assets/kit/pickups/Pickup_Crate.gltf").instantiate()
	vp.add_child(crate)
	KitUtil.fit_height(crate, 0.5)
	crate.position += Vector3(0.6, 0.0, 0.5)
	crate.rotation_degrees.y = -25
	CelShading.apply(crate)

	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.position = Vector3(0.35, 1.05, 4.6)
	cam.look_at(Vector3(0.25, 0.85, 0.0))
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("icone: ", out)
	quit()

func _pose(model: Node, anim: String) -> void:
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false).front() if not model.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	if ap and ap.has_animation(anim):
		ap.play(anim)
		ap.seek(0.55, true)
		ap.pause()
