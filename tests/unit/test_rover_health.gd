extends GutTest
## Vida do rover: dano por quedas, explosão a 0, renascer na base, reparação.

var run: Node3D

func before_each() -> void:
	run = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(60)

func after_each() -> void:
	Input.action_release("vehicle")

func test_hard_fall_damages_the_rover() -> void:
	var rover: Rover = run.rover
	# Longe da base (junto à base repara-se sozinho).
	var lair: Vector3 = run.planet.data.lair_dir
	rover.place_at(run.planet.to_global(run.planet.data.surface_point(lair) + lair * 9.0), rover.forward())
	var before := rover.health
	await wait_physics_frames(120)
	assert_lt(rover.health, before, "cair de 9 m devia tirar vida")
	assert_true(rover.alive)

func test_damage_to_zero_destroys_once() -> void:
	var rover: Rover = run.rover
	watch_signals(rover)
	rover.take_damage(60.0)
	rover.take_damage(60.0)
	rover.take_damage(60.0)
	assert_signal_emit_count(rover, "destroyed", 1)
	assert_false(rover.alive)
	assert_eq(rover.health, 0.0)

func test_explosion_fails_order_and_respawns_at_base() -> void:
	var dc: DeliveryController = run.deliveries
	var o: DeliveryOrder = dc.session.offers[0]
	dc.accept(o)
	dc.session.pick_up()
	run.enter_rover()
	# Longe do destino e da base, para não entregar nem reparar.
	run.teleport(run.planet.data.lair_dir)
	await wait_physics_frames(10)
	run.rover.take_damage(999.0)
	await wait_physics_frames(5)
	assert_eq(o.state, DeliveryOrder.State.FAILED, "a encomenda devia falhar")
	assert_eq(o.paid, 0)
	assert_true(run.respawning)
	# Durante a explosão vê-se o carro: visível, carbonizado, câmara mais afastada, câmara lenta.
	assert_true(run.rover.visible, "o carro devia continuar à vista a explodir")
	assert_true(run.rover.is_charred())
	assert_not_null(run.explosion, "devia haver uma explosão")
	assert_eq(run.explosion.debris.size(), 4, "as 4 rodas deviam soltar-se")
	assert_false(run.rover.wheels_attached())
	assert_lt(Engine.time_scale, 1.0, "devia começar em câmara lenta")
	assert_eq(run.camera.distance, run.CAM_WRECK.distance)
	await wait_seconds(2.0)
	assert_true(run.respawning, "ainda não devia ter renascido (dá tempo para ver)")
	assert_true(run.rover.visible)
	await wait_seconds(run.RESPAWN_DELAY)
	assert_eq(Engine.time_scale, 1.0, "a câmara lenta devia ter acabado")
	assert_almost_eq(run._fade_rect.color.a, 0.0, 0.01, "o ecrã devia voltar a clarear")
	assert_false(run.rover.is_charred(), "o rover novo não vem carbonizado")
	assert_true(run.rover.wheels_attached(), "o rover novo vem com as rodas")
	assert_false(run.respawning)
	assert_false(run.driving, "devia renascer a pé")
	assert_true(run.player.visible)
	assert_true(run.rover.alive)
	assert_eq(run.rover.health, run.rover.max_health)
	var base: Vector3 = run.planet.to_global(run.planet.data.surface_point(run.planet.data.outpost_dir))
	assert_lt(run.player.global_position.distance_to(base), 20.0, "devia renascer junto à base")

func test_parked_near_base_repairs() -> void:
	var rover: Rover = run.rover
	assert_true(run.rover_near_base(), "o rover começa junto à base")
	rover.take_damage(50.0)
	var damaged := rover.health
	await wait_seconds(1.5)
	assert_gt(rover.health, damaged + 10.0, "devia estar a reparar")

func test_far_from_base_does_not_repair() -> void:
	var rover: Rover = run.rover
	run.enter_rover()
	run.teleport(run.planet.data.lair_dir)
	await wait_physics_frames(60)
	rover.take_damage(30.0)
	var damaged := rover.health
	await wait_seconds(1.0)
	assert_almost_eq(rover.health, damaged, 0.01)
