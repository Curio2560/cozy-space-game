extends GutTest
## Vida e O₂ na cena: o O₂ gasta-se a pé e não dentro do rover; desmaiar falha a encomenda e
## acorda-se na base com tudo cheio.

var run: Node3D

func before_each() -> void:
	run = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(60)

func test_o2_drains_on_foot_and_shows_bar() -> void:
	assert_false(run.bars.is_shown("o2"), "sem gasto não há barra de O₂")
	run.extra_o2_drain = 20.0
	await wait_seconds(1.0)
	assert_lt(run.vitals.o2, PlayerVitals.MAX_O2)
	assert_true(run.bars.is_shown("o2"))

func test_rover_cabin_protects_o2() -> void:
	run.enter_rover()
	run.extra_o2_drain = 20.0
	await wait_seconds(1.0)
	assert_eq(run.vitals.o2, PlayerVitals.MAX_O2, "dentro do rover o O₂ não se gasta")

func test_faint_fails_order_and_wakes_at_base() -> void:
	var dc: DeliveryController = run.deliveries
	var o: DeliveryOrder = dc.session.offers[0]
	dc.accept(o)
	dc.session.pick_up()
	run.teleport(run.planet.data.lair_dir)
	await wait_physics_frames(20)
	run.vitals.damage(500.0)
	await wait_physics_frames(2)
	assert_true(run.respawning)
	assert_true(run.player.downed, "o astronauta devia estar caído")
	assert_eq(o.state, DeliveryOrder.State.FAILED)
	await wait_seconds(run.FAINT_TIME + run.FADE_TIME * 2.0 + 0.6)
	assert_false(run.respawning)
	assert_false(run.player.downed)
	assert_true(run.player.controllable)
	assert_eq(run.vitals.health, PlayerVitals.MAX_HEALTH)
	var base: Vector3 = run.planet.to_global(run.planet.data.surface_point(run.planet.data.outpost_dir))
	assert_lt(run.player.global_position.distance_to(base), 20.0)

func test_no_o2_leads_to_faint() -> void:
	run.vitals.o2 = 1.0
	run.extra_o2_drain = 30.0
	await wait_seconds(7.0)
	assert_true(run.respawning or run.vitals.health < 10.0, "sem O₂ a vida devia esgotar")
