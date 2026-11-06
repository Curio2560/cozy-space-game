extends GutTest
## Smoke test do astronauta num planeta: com input simulado anda à volta sem cair,
## continua alinhado com a superfície e salta em qualquer ponto.

var run: Node3D

func before_each() -> void:
	run = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await _land()

func after_each() -> void:
	for a in ["move_forward", "move_right", "jump"]:
		Input.action_release(a)

func _land() -> void:
	for i in 180:
		await wait_physics_frames(1)
		if run.player.is_on_floor():
			return

func _height_above_ground() -> float:
	var d: PlanetData = run.planet.data
	var local: Vector3 = run.planet.to_local(run.player.global_position)
	return local.length() - (d.radius + d.height_at(local.normalized()))

func test_lands_on_surface_aligned() -> void:
	assert_true(run.player.is_on_floor(), "devia estar no chão")
	assert_almost_eq(_height_above_ground(), 0.0, 0.35)
	assert_gt(run.player.global_basis.y.dot(run.player.up()), 0.99, "corpo desalinhado")

func test_walks_a_long_way_staying_on_surface() -> void:
	var start: Vector3 = run.player.up()
	Input.action_press("move_forward", 1.0)
	var worst := 0.0
	for i in 20:
		await wait_physics_frames(30)
		worst = maxf(worst, absf(_height_above_ground()))
		assert_gt(run.player.global_basis.y.dot(run.player.up()), 0.98, "corpo desalinhado ao andar")
	Input.action_release("move_forward")
	var arc: float = start.angle_to(run.player.up()) * run.planet.data.radius
	assert_gt(arc, 25.0, "devia ter andado bastante à volta do planeta (andou %.1f m)" % arc)
	# Saltinhos em lombas são normais; cair pelo planeta ou flutuar não.
	assert_lt(worst, 2.5, "afastou-se %.2f m da superfície" % worst)

func test_jumps_anywhere_on_the_planet() -> void:
	for dir in [Vector3.UP, Vector3.DOWN, Vector3(1, 0, 0), Vector3(0, -0.3, 1).normalized()]:
		run.teleport(dir)
		await _land()
		Input.action_press("jump")
		var peak := 0.0
		for i in 25:
			await wait_physics_frames(1)
			peak = maxf(peak, _height_above_ground())
		Input.action_release("jump")
		assert_gt(peak, 1.0, "não saltou em %s (%.2f m)" % [dir, peak])
		await _land()
		assert_true(run.player.is_on_floor(), "não voltou ao chão em %s" % dir)

func test_camera_stays_above_the_ground_behind_player() -> void:
	Input.action_press("move_forward", 1.0)
	await wait_physics_frames(60)
	Input.action_release("move_forward")
	var cam: Camera3D = run.camera
	var up: Vector3 = run.player.up()
	var to_player: Vector3 = run.player.global_position - cam.global_position
	assert_gt((cam.global_position - run.player.global_position).dot(up), 0.5, "câmara devia estar acima do jogador")
	assert_lt(to_player.length(), 12.0)
	assert_gt(-cam.global_basis.z.dot(to_player.normalized()), 0.8, "câmara devia olhar para o jogador")
