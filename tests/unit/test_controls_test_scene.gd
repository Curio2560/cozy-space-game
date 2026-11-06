extends GutTest
## Smoke test da cena de controlos: com input simulado o cubo anda e salta.

var scene: Node3D

func before_each() -> void:
	scene = (load("res://scenes/dev/controls_test.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	# O cubo nasce um pouco acima do chão: esperar que assente.
	for i in 120:
		await wait_physics_frames(1)
		if scene.player.is_on_floor():
			break

func after_each() -> void:
	Input.action_release("move_forward")
	Input.action_release("jump")

func test_player_moves_forward_with_input() -> void:
	var start: Vector3 = scene.player.position
	Input.action_press("move_forward", 1.0)
	await wait_physics_frames(30)
	Input.action_release("move_forward")
	var moved: float = Vector2(scene.player.position.x - start.x, scene.player.position.z - start.z).length()
	assert_gt(moved, 1.5, "o cubo devia ter andado (andou %.2f)" % moved)
	assert_almost_eq(scene.player.position.y, 0.0, 0.1, "devia continuar no chão")

func test_player_jumps() -> void:
	assert_true(scene.player.is_on_floor())
	Input.action_press("jump")
	await wait_physics_frames(8)
	Input.action_release("jump")
	assert_gt(scene.player.position.y, 0.5, "o cubo devia estar no ar")
	await wait_physics_frames(90)
	assert_almost_eq(scene.player.position.y, 0.0, 0.1, "devia voltar ao chão")
