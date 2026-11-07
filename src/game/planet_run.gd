extends Node3D
## Protótipo da F1: um planeta gerado, o astronauta, o rover e a câmara.
## (As entregas entram no ticket #8.)

const ENTER_DISTANCE := 5.0
const REPAIR_RADIUS := 16.0 # junto ao posto avançado
const REPAIR_RATE := 20.0 # vida por segundo, parado junto à base
const WRECK_TIME := 6.5 # segundos (reais) a ver a explosão e os destroços antes de escurecer
const FADE_TIME := 0.5
const SLOWMO := 0.35 # câmara lenta no início da explosão
const SLOWMO_TIME := 1.6
const RESPAWN_DELAY := WRECK_TIME + FADE_TIME * 2.0 # tempo total até voltar a jogar
const CAM_WRECK := {"distance": 15.0, "pitch": -0.42, "focus_height": 2.0, "auto_return_delay": 999.0}
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
var vitals := PlayerVitals.new()
var creatures: Array[Creature] = []
const CREATURE_MIN_BASE_M := 30.0
const CREATURE_MIN_POST_M := 12.0
const ATTACK_DAMAGE := 8.0
const ATTACK_ROVER_DAMAGE := 4.0
const PUSH_SPEED := 4.0 # m/s do encontrão (para o lado, sem atirar ao ar)
const RAM_SPEED := 6.0 # o rover a esta velocidade atropela e afugenta
var explosion: RoverExplosion
var dust: CPUParticles3D
var deliveries: DeliveryController
var bubbles: O2Bubbles
var heat := RoverHeat.new()
var ambient: AmbientParticles

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
	dust = _make_dust()
	rover.add_child(dust)
	_build_ui()
	builder = ModuleBuilder.new()
	builder.name = "ModuleBuilder"
	add_child(builder)
	deliveries = DeliveryController.new()
	deliveries.name = "Deliveries"
	add_child(deliveries)
	deliveries.setup(self, wallet, _hud_layer)
	bars = StatusBars.new()
	_hud_layer.add_child(bars)
	bars.add_bar("rover", "BAR_ROVER", Color("ff9f5a"))
	rover.health_changed.connect(func(v: float, m: float) -> void: bars.set_value("rover", v, m))
	bars.set_value("rover", rover.health, rover.max_health)
	bars.add_bar("health", "BAR_HEALTH", Color("ff6b8a"))
	bars.add_bar("o2", "BAR_O2", Color("6fd6ff"))
	bars.add_bar("heat", "BAR_HEAT", Color("ff5a2a"))
	heat.changed.connect(func() -> void: bars.set_value("heat", heat.heat, RoverHeat.MAX))
	heat.overheated.connect(func() -> void: deliveries.hud.toast(tr("TOAST_OVERHEAT")))
	vitals.changed.connect(_update_vital_bars)
	vitals.fainted.connect(_on_player_fainted)
	_update_vital_bars()
	var saved := SaveGame.read() if SaveGame.active else {}
	if not saved.is_empty():
		var pl: Dictionary = saved.get("planet", {})
		seed_value = int(pl.get("seed", seed_value))
		biome = str(pl.get("biome", biome))
	start(seed_value)
	if not saved.is_empty():
		apply_state(saved)
	_register_debug()
	builder.setup(self)
	var args := OS.get_cmdline_user_args() # argumentos só para capturas de ecrã no PC
	if "dbgbuild" in args: # capturas: modo construção com uma casa colocada
		builder.enter_mode()
		builder.selected = "★ Casa do colono"
		builder._refresh_ghost()
		builder.place()
		builder.selected = "Props_Pod"
		builder.rotate_90()
		builder._refresh_ghost()
		player.place_at(player.global_position + (-camera.global_basis.z) * -3.0)
	if "pause" in args:
		pause_menu.open()
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
	if "post" in args: # junto ao primeiro posto, a olhar para a casa (capturas)
		var door := planet.data.post_doors[0]
		var back := planet.data.toward_point(door, planet.data.posts[0], -9.0)
		teleport(back)
		player.facing = (planet.to_global(planet.data.surface_point(planet.data.posts[0])) - player.global_position).normalized()
		camera.set_target(player, player.facing)
	if "monsters" in args: # traz algumas criaturas para perto (capturas)
		var pd := planet.to_local(player.global_position).normalized()
		var f := planet.global_basis.inverse() * (-camera.global_basis.z)
		f = (f - pd * f.dot(pd)).normalized()
		var side := pd.cross(f).normalized()
		for i in mini(5, creatures.size()):
			var c: Creature = creatures[i * 3 % creatures.size()]
			var m := 7.0 + i * 3.0
			var p := pd + f * (m / planet.data.radius) + side * ((i - 2) * 2.5 / planet.data.radius)
			c.teleport_to(p.normalized())
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

## Estado do jogo para o save. Cada sistema acrescenta a sua secção.
func save_state() -> Dictionary:
	return {
		"planet": {"seed": seed_value, "biome": biome},
		"wallet": wallet.to_dict(),
		"deliveries": deliveries.session.to_dict(),
	}

## Repõe as secções de um save (o planeta já foi gerado com a seed guardada).
func apply_state(state: Dictionary) -> void:
	wallet.from_dict(state.get("wallet", {}))
	deliveries.session.from_dict(state.get("deliveries", {}))
	deliveries._update_keycards()

## Guarda se o save estiver ativo (aberto pelo menu). Chamado ao entregar, construir e sair.
func autosave() -> void:
	if SaveGame.active:
		SaveGame.write(save_state())

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		if is_node_ready() and deliveries and deliveries.session:
			autosave()

## Começa um jogo novo: apaga o save, zera a carteira e gera um planeta novo (prado).
func new_game() -> void:
	SaveGame.erase()
	wallet.from_dict({})
	biome = "prado"
	start(randi() % 100000)

## Gera o planeta `s` e põe o jogador junto ao posto avançado.
func start(s: int) -> void:
	seed_value = s
	planet.build(PlanetGenerator.generate(s, biome))
	bubbles = O2Bubbles.new()
	bubbles.name = "O2Bubbles"
	planet.add_child(bubbles) # planet.build apaga os filhos: recriar a cada planeta
	bubbles.setup(planet.data)
	heat.reset()
	_apply_biome_sky()
	if ambient:
		ambient.queue_free()
	ambient = AmbientParticles.new()
	ambient.name = "Ambient"
	add_child(ambient)
	ambient.planet_center = planet.global_position
	ambient.target = player
	ambient.setup(biome)
	player.planet_center = planet.global_position
	camera.planet_center = planet.global_position
	rover.planet_center = planet.global_position
	rover.ground_radius = func(pos: Vector3) -> float:
		return planet.data.surface_point(planet.to_local(pos)).length()
	if driving:
		exit_rover()
	spawn_near(planet.data.outpost_dir, planet.data.posts[0], 10.5)
	_park_rover_near_player()
	if deliveries:
		deliveries.start_planet(planet.data)
	_spawn_creatures()
	deliveries.session.order_delivered.connect(func(_o: DeliveryOrder, _t: bool) -> void: autosave())
	autosave()
	if builder:
		builder.clear()

## Espalha as criaturas do bioma pelo planeta (determinístico pela seed), longe da base e dos postos.
func _spawn_creatures() -> void:
	for c in creatures:
		c.queue_free()
	creatures.clear()
	var d := planet.data
	var n: int = PlanetGenerator.BIOMES[biome].get("creatures", 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(d.seed * 131 + 7)
	var ids := CreatureCatalog.ids()
	var tries := 0
	while creatures.size() < n and tries < n * 20:
		tries += 1
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if d.arc_m(dir, d.outpost_dir) < CREATURE_MIN_BASE_M:
			continue
		if d.posts.any(func(p: Vector3) -> bool: return d.arc_m(dir, p) < CREATURE_MIN_POST_M):
			continue
		var c := Creature.new()
		c.name = "Creature%d" % creatures.size()
		add_child(c)
		c.setup(ids[rng.randi() % ids.size()], planet, dir, biome, rng.randi())
		c.target = _creature_target
		c.attacked.connect(_on_creature_attack)
		c.dropped_crate.connect(_on_crate_dropped)
		c.target_has_crate = func() -> bool: return deliveries.session != null and deliveries.session.carrying()
		creatures.append(c)
	for c in creatures:
		c.flock = creatures

func _creature_target() -> Node3D:
	return rover if driving else player

## Uma criatura apanhou o jogador (ou o rover): empurra, tira vida e pode estragar ou roubar a encomenda.
func _on_creature_attack(c: Creature) -> void:
	if respawning:
		return
	var t := _creature_target()
	var away := (t.global_position - c.global_position)
	var up := (t.global_position - planet.global_position).normalized()
	away = (away - up * away.dot(up)).normalized()
	if driving:
		rover.take_damage(ATTACK_ROVER_DAMAGE)
		rover.apply_central_impulse(away * 1.2 * rover.mass) # empurrão lateral, sem atirar ao ar
		return
	vitals.damage(ATTACK_DAMAGE)
	player.add_push(away * PUSH_SPEED)
	var s := deliveries.session
	if s and s.carrying():
		if randf() < c.steal_chance and s.steal():
			c.take_crate()
			deliveries.thief = c
			deliveries.hud.toast(tr("TOAST_STOLEN"))
		else:
			s.damage_active()
			deliveries.hud.toast(tr("TOAST_BUMPED"))

func _on_crate_dropped(c: Creature, at: Vector3) -> void:
	if deliveries.session and deliveries.session.drop(at):
		deliveries.thief = null
		deliveries.hud.toast(tr("TOAST_DROPPED"))

## O rover depressa atropela e afugenta as criaturas (sem se estragar).
func _check_rams() -> void:
	if not driving or rover.linear_velocity.length() < RAM_SPEED:
		return
	for c in creatures:
		if c.mode != Creature.Mode.KNOCKED and c.global_position.distance_to(rover.global_position) < 2.6:
			c.knock(rover.global_position)

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

## Explosão do rover: um momento para ver. Câmara lenta, o carro salta carbonizado, a câmara
## afasta-se; depois o ecrã escurece, renasces na base com o rover novo e o ecrã volta a clarear.
## A encomenda em curso falha.
func _on_rover_destroyed() -> void:
	respawning = true
	explosion = RoverExplosion.new()
	add_child(explosion)
	explosion.start(rover.global_position, rover.planet_up(), planet.global_position, rover)
	rover.wreck()
	if driving:
		camera.set_target(rover, rover.forward())
	_apply_camera(CAM_WRECK)
	camera.target_facing = Callable()
	deliveries.hud.toast(tr("TOAST_ROVER_EXPLODED"))
	if deliveries.session and deliveries.session.fail_active():
		deliveries.hud.toast(tr("TOAST_ROVER_EXPLODED") + "\n" + tr("TOAST_ORDER_LOST"))
	Engine.time_scale = SLOWMO
	await _real_seconds(SLOWMO_TIME)
	Engine.time_scale = 1.0
	await _real_seconds(WRECK_TIME - SLOWMO_TIME)
	if not is_inside_tree():
		return
	await _respawn_at_base()

## Escurece, põe o jogador (a pé, com vida e O₂ cheios) junto à base com o rover novo ao lado,
## e clareia. Usado depois da explosão do rover e do desmaio.
func _respawn_at_base() -> void:
	await _fade(1.0)
	if driving:
		driving = false
		rover.driven = false
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.visible = true
		player.collision_layer = 2
	player.revive()
	vitals.reset()
	spawn_near(planet.data.outpost_dir, planet.data.posts[0], 10.5)
	rover.restore()
	_park_rover_near_player()
	await _fade(0.0)
	respawning = false

const FAINT_TIME := 2.2 # segundos a ver o astronauta caído antes de escurecer

## Desmaio (vida a 0, p. ex. sem O₂): cai, a encomenda falha, acorda na base.
func _on_player_fainted() -> void:
	if respawning:
		return
	respawning = true
	player.faint()
	deliveries.hud.toast(tr("TOAST_FAINTED"))
	if deliveries.session and deliveries.session.fail_active():
		deliveries.hud.toast(tr("TOAST_FAINTED") + "\n" + tr("TOAST_ORDER_LOST"))
	await _real_seconds(FAINT_TIME)
	if not is_inside_tree():
		return
	await _respawn_at_base()

## Taxa de gasto de O₂ onde o jogador está (a pé): o ar do bioma, mais junto aos rios de ácido.
func o2_drain_here() -> float:
	var bd: Dictionary = PlanetGenerator.BIOMES[biome]
	var base := float(bd.get("o2_drain", 0.0))
	var near_k := float(bd.get("rivers", {}).get("o2_near", 1.0))
	return AcidHazard.o2_drain(planet.data, planet.to_local(player.global_position), base, near_k) + extra_o2_drain

## Calor do rover nos biomas com "rover_heat" (lava): aquece a andar e junto às fissuras,
## arrefece parado e à sombra; sobreaquecido fica lento.
func _apply_heat(delta: float) -> void:
	var on := bool(PlanetGenerator.BIOMES[biome].get("rover_heat", false))
	bars.show_bar("heat", on and (driving or heat.heat > 0.0))
	if not on or not rover.alive:
		rover.speed_factor = 1.0
		return
	var here := planet.to_local(rover.global_position)
	var spd := rover.linear_velocity.length()
	var clear := planet.data.river_clearance(here)
	for h in rover.wheel_hits:
		if h is Array and h.size() > 1 and h[0]:
			clear = minf(clear, planet.data.river_clearance(planet.to_local(h[1])))
	heat.tick(delta, spd, spd / rover.max_speed, clear, RoverHeat.in_shade(planet.data, here))
	rover.speed_factor = heat.speed_factor()

## Dano/s do rio ao rover: conta se o centro ou qualquer roda estiver no ácido/lava.
func _rover_liquid_rate(d: PlanetData) -> float:
	var best := AcidHazard.rover_damage_rate(d, planet.to_local(rover.global_position))
	for h in rover.wheel_hits:
		if h is Array and h.size() > 1 and h[0]:
			best = maxf(best, AcidHazard.rover_damage_rate(d, planet.to_local(h[1])))
	return best

## Perigos do ácido neste frame: dano a pé ou ao rover dentro do rio, bolhas de O₂.
func _apply_hazards(delta: float) -> void:
	var d := planet.data
	_apply_heat(delta)
	# O rover estraga-se no ácido, conduzido ou estacionado.
	if rover.alive:
		var rr := _rover_liquid_rate(d)
		if rr > 0.0:
			rover.take_damage(rr * delta)
	if driving:
		return
	var here := planet.to_local(player.global_position)
	vitals.damage(AcidHazard.foot_damage_rate(d, here) * delta)
	if bubbles:
		var got := bubbles.collect(here)
		if got > 0.0:
			vitals.add_o2(got)

## Gasto extra definido pelos perigos ou pelo DBG.
var extra_o2_drain := 0.0

func _update_vital_bars() -> void:
	bars.set_value("health", vitals.health, PlayerVitals.MAX_HEALTH)
	bars.set_value("o2", vitals.o2, PlayerVitals.MAX_O2)
	bars.show_bar("health", vitals.health < PlayerVitals.MAX_HEALTH)
	bars.show_bar("o2", vitals.o2_drain > 0.0 or vitals.o2 < PlayerVitals.MAX_O2)

func _real_seconds(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

var _fade_rect: ColorRect

## Escurece (1.0) ou clareia (0.0) o ecrã.
func _fade(to_alpha: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_fade_rect, "color:a", to_alpha, FADE_TIME)
	await tw.finished

func _exit_tree() -> void:
	Engine.time_scale = 1.0

## Fumo/pó que sai das rodas do rover quando anda.
func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	sm.material = mat
	p.mesh = sm
	p.amount = 60
	p.lifetime = 1.8
	p.local_coords = false
	p.emitting = false
	p.position = Vector3(0, 0.2, -1.3)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.0, 0.1, 0.2)
	p.direction = Vector3(0, 0.6, -1)
	p.spread = 35.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3.ZERO
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.6))
	sc.add_point(Vector2(1.0, 3.0))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(0.88, 0.8, 0.7, 0.6))
	g.set_color(1, Color(0.75, 0.72, 0.72, 0.0))
	p.color_ramp = g
	return p

## Fumo/pó a sair das rodas quando o rover anda.
func _update_tracks() -> void:
	dust.emitting = rover.alive and rover.grounded_wheels >= 2 and rover.linear_velocity.length() > 2.5

func rover_near_base() -> bool:
	return rover.global_position.distance_to(planet.to_global(planet.data.surface_point(planet.data.outpost_dir))) < REPAIR_RADIUS

func _physics_process(delta: float) -> void:
	if rover.alive and rover.health < rover.max_health and rover_near_base() and rover.linear_velocity.length() < 1.0:
		rover.repair(REPAIR_RATE * delta)
	bars.show_bar("rover", driving or rover.health < rover.max_health)
	_check_rams()
	_update_tracks()
	if not respawning:
		# A cabine do rover protege: lá dentro o O₂ não se gasta.
		vitals.o2_drain = 0.0 if driving else o2_drain_here()
		vitals.tick(delta)
		_apply_hazards(delta)
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
var sky_planets: SkyPlanets
var _sky_mat: ShaderMaterial

## Céu e luz ambiente de cada bioma.
func _apply_biome_sky() -> void:
	var sky: Dictionary = PlanetGenerator.BIOMES[biome].get("sky", {})
	_env.background_color = sky.get("bg", Color("2b2146"))
	_sky_mat.set_shader_parameter("base_color", sky.get("bg", Color("2b2146")))
	_sky_mat.set_shader_parameter("nebula_a", sky.get("nebula_a", Color("5b3f94")))
	_sky_mat.set_shader_parameter("nebula_b", sky.get("nebula_b", Color("ff9f7a")))
	sky_planets.setup(sky.get("planets", []))
	_env.ambient_light_color = sky.get("ambient", Color("b9a8e8"))
	sun.light_color = sky.get("sun", Color("fff1dc"))

func _build_world() -> void:
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9a8e8")
	env.ambient_light_energy = 0.5
	# Céu: shader de estrelas e nebulosas + planetas animados (cores por bioma).
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://shaders/space_sky.gdshader")
	var sky_res := Sky.new()
	sky_res.sky_material = _sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_env = env
	sky_planets = SkyPlanets.new()
	sky_planets.name = "SkyPlanets"
	add_child(sky_planets)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	add_child(sun)

## Até existir o ciclo dia/noite (F4) o sol acompanha o jogador: é sempre de dia onde ele está.
func _process(_delta: float) -> void:
	# Árvores entre a câmara e quem se segue (a pé ou no rover) ficam pontilhadas.
	var who: Node3D = rover if driving else player
	CelShading.set_occlusion(camera.global_position, who.global_position + (who.global_position - planet.global_position).normalized() * 0.8)
	if ambient:
		ambient.target = who
	var u := rover.planet_up() if driving else player.up()
	var side := SphereMath.basis_from_up(u).x
	var light_dir := -(u * 0.75 + side * 0.45 + camera.global_basis.z * 0.25).normalized()
	sun.look_at_from_position(Vector3.ZERO, light_dir, u if absf(light_dir.dot(u)) < 0.99 else side)

var _hud_layer: CanvasLayer
var pause_menu: PauseMenu
var builder: ModuleBuilder
var minimap: Minimap

## Nó que o jogador está a controlar (rover ou astronauta).
func carrier_node() -> Node3D:
	return rover if driving else player

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
	var pause_btn := Button.new()
	pause_btn.name = "PauseButton"
	pause_btn.icon = CozyTheme.icon(CozyTheme.ICON_PAUSE)
	pause_btn.expand_icon = true
	pause_btn.position = Vector2(20, 14)
	pause_btn.custom_minimum_size = Vector2(68, 68)
	pause_btn.size = Vector2(68, 68)
	pause_btn.pressed.connect(func() -> void: pause_menu.open())
	hud.add_child(pause_btn)
	minimap = Minimap.new()
	minimap.run = self
	hud.add_child(minimap)
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -Minimap.SIZE - 20.0
	minimap.offset_right = -20.0
	minimap.offset_top = 76.0
	minimap.offset_bottom = 76.0 + Minimap.SIZE
	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 60
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	pause_menu = PauseMenu.new()
	pause_layer.add_child(pause_menu)
	pause_menu.new_planet.connect(func() -> void: start(randi() % 100000))
	pause_menu.new_game.connect(new_game)
	pause_menu.quit_to_menu.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/boot.tscn"))
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 50
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.08, 0.05, 0.12, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade_rect)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y = 24
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_color", CozyTheme.CREAM)
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
	DebugMenu.default_tab = "DBG_TAB_WORLD"
	DebugMenu.add_label(self, func() -> String: return "%s · seed %d · %d ¢" % [biome, seed_value, wallet.credits()])
	DebugMenu.add_button(self, "DBG_NEW_SEED", func() -> void: start(randi() % 100000))
	DebugMenu.add_button(self, "DBG_NEXT_BIOME", func() -> void:
		var names := PlanetGenerator.BIOMES.keys()
		biome = names[(names.find(biome) + 1) % names.size()]
		start(seed_value))
	DebugMenu.add_button(self, "DBG_GOTO_OUTPOST", func() -> void:
		spawn_near(planet.data.outpost_dir, planet.data.posts[0], 10.5))
	for i in 3:
		DebugMenu.add_button(self, tr("DBG_GOTO_POST") + " %d" % (i + 1), func() -> void:
			spawn_near(planet.data.posts[i], planet.data.outpost_dir, 7.0))
	DebugMenu.default_tab = "DBG_TAB_PLAYER"
	DebugMenu.add_slider(self, "DBG_SPEED", 2.0, 16.0, 0.5, player.walk_speed, func(v: float) -> void: player.walk_speed = v)
	DebugMenu.add_slider(self, "DBG_JUMP", 3.0, 16.0, 0.5, player.jump_velocity, func(v: float) -> void: player.jump_velocity = v)
	DebugMenu.add_slider(self, "DBG_GRAVITY", 5.0, 40.0, 1.0, player.gravity, func(v: float) -> void: player.gravity = v)
	DebugMenu.add_slider(self, "DBG_CAM_DIST", 3.0, 14.0, 0.5, camera.distance, func(v: float) -> void: camera.distance = v)
	DebugMenu.default_tab = "DBG_TAB_ROVER"
	DebugMenu.add_slider(self, "DBG_ROVER_SPEED", 6.0, 30.0, 1.0, rover.max_speed, func(v: float) -> void: rover.max_speed = v)
	DebugMenu.add_slider(self, "DBG_ROVER_TURN", 0.8, 4.0, 0.1, rover.turn_rate, func(v: float) -> void: rover.turn_rate = v)
	DebugMenu.add_slider(self, "DBG_ROVER_SPRING", 2000.0, 9000.0, 100.0, rover.spring_k, func(v: float) -> void: rover.spring_k = v)
	DebugMenu.add_button(self, "DBG_ADD_CREDITS", func() -> void: wallet.add(Wallet.CREDITS, 500), "DBG_TAB_GENERAL")
	DebugMenu.default_tab = "DBG_TAB_WORLD"
	DebugMenu.add_slider(self, "DBG_SKY_BRIGHT", 0.3, 2.0, 0.05, 1.0, func(v: float) -> void: _sky_mat.set_shader_parameter("brightness", v))
	DebugMenu.add_slider(self, "DBG_SKY_NEBULA", 0.0, 1.0, 0.05, 0.55, func(v: float) -> void: _sky_mat.set_shader_parameter("nebula_strength", v))
	# F2: relevo, ácido/lava, partículas.
	DebugMenu.add_button(self, "DBG_GOTO_RELIEF", func() -> void:
		var d := planet.data
		if d.reliefs.is_empty():
			return
		var r: Dictionary = d.reliefs[randi() % d.reliefs.size()]
		var foot: float = ReliefKit.piece(r.kind).radius * float(r.scale)
		teleport(d.toward_point(r.dir, r.dir + SphereMath.basis_from_up(r.dir).z, foot + 3.0)))
	DebugMenu.add_button(self, "DBG_GOTO_RIVER", func() -> void:
		var d := planet.data
		if d.rivers.is_empty():
			return
		var rv: Dictionary = d.rivers[randi() % d.rivers.size()]
		var pts: PackedVector3Array = rv.points
		var p := pts[pts.size() / 2]
		var side := p.cross(pts[pts.size() / 2 + 1] - p).normalized()
		teleport((p + side * tan((float(rv.width) * 0.5 + 3.0) / d.radius)).normalized()))
	DebugMenu.add_toggle(self, "DBG_PARTICLES", true, func(on: bool) -> void:
		if ambient:
			ambient.visible = on)
	DebugMenu.add_button(self, "DBG_HEAT", func() -> void:
		heat.heat = minf(heat.heat + 50.0, RoverHeat.MAX - 0.01)
		heat.changed.emit(), "DBG_TAB_ROVER")
	DebugMenu.default_tab = "DBG_TAB_CREATURES"
	DebugMenu.add_toggle(self, "DBG_CREATURES", true, func(on: bool) -> void:
		for c in creatures:
			c.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
			c.visible = on)
	DebugMenu.add_button(self, "DBG_CREATURE_HERE", func() -> void:
		if creatures.is_empty():
			return
		var c: Creature = creatures[0]
		var pd := planet.to_local(player.global_position).normalized()
		c.teleport_to(pd.rotated(SphereMath.basis_from_up(pd).x, 6.0 / planet.data.radius)))
	DebugMenu.default_tab = "DBG_TAB_PLAYER"
	DebugMenu.add_button(self, "DBG_HURT", func() -> void: vitals.damage(30.0))
	DebugMenu.add_toggle(self, "DBG_O2_DRAIN", false, func(on: bool) -> void: extra_o2_drain = 12.0 if on else 0.0)
	DebugMenu.default_tab = "DBG_TAB_ROVER"
	DebugMenu.add_button(self, "DBG_ROVER_DAMAGE", func() -> void: rover.take_damage(40.0))
	DebugMenu.add_slider(self, "DBG_ROVER_BOUNCE", 80.0, 600.0, 10.0, rover.spring_damp, func(v: float) -> void: rover.spring_damp = v)
	DebugMenu.add_slider(self, "DBG_ROVER_SPIN", 0.0, 4.0, 0.1, rover.spin_damp, func(v: float) -> void: rover.spin_damp = v)
	DebugMenu.add_slider(self, "DBG_ROVER_AIR", 0.0, 8.0, 0.2, rover.air_align, func(v: float) -> void: rover.air_align = v)
	DebugMenu.add_button(self, "DBG_ROVER_HERE", func() -> void:
		if driving:
			exit_rover()
		_park_rover_near_player())
	DebugMenu.default_tab = DebugMenu.GENERAL
