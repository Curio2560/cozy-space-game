extends GutTest
## Fluxo de ponta a ponta na cena: quadro, aceitar, apanhar a caixa e entregar.

var run: Node3D

func before_each() -> void:
	run = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(30)

func after_each() -> void:
	Input.action_release("action")

func test_colonist_names_float_over_houses() -> void:
	# Letreiros com os nomes dos colonos (os dos slots do posto ficam de fora).
	var labels := run.find_children("*", "Label3D", true, false).filter(func(l: Node) -> bool: return not l.get_parent().name.begins_with("Slot"))
	assert_eq(labels.size(), 3)

func test_board_opens_near_outpost_with_action() -> void:
	var dc: DeliveryController = run.deliveries
	assert_true(dc.near_board(), "o jogador começa perto do posto avançado")
	Input.action_press("action")
	await wait_physics_frames(3)
	Input.action_release("action")
	assert_true(dc.board_open)
	assert_false(run.touch.visible, "os controlos táteis escondem-se com o quadro aberto")
	dc.close_board()
	assert_false(dc.board_open)

func test_accept_pick_up_and_deliver_pays_credits() -> void:
	var dc: DeliveryController = run.deliveries
	var o: DeliveryOrder = dc.session.offers[0]
	assert_true(dc.accept(o))
	run.spawn_near(run.planet.data.posts[o.from_post], run.planet.data.outpost_dir, 3.5)
	await wait_physics_frames(20)
	assert_eq(o.state, DeliveryOrder.State.CARRYING, "devia ter apanhado a caixa ao chegar ao posto")
	var before: int = run.wallet.credits()
	run.spawn_near(run.planet.data.posts[o.to_post], run.planet.data.outpost_dir, 4.0)
	await wait_physics_frames(20)
	assert_eq(o.state, DeliveryOrder.State.DELIVERED, "devia ter entregue ao chegar ao destino")
	assert_gt(run.wallet.credits(), before)
	assert_null(dc.session.active)
