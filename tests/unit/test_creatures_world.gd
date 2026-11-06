extends GutTest
## Criaturas nos planetas: onde nascem, andam à superfície, perseguem e atacam, roubam a caixa
## (largam-na ao toque) e fogem do rover em velocidade.

var run: Node3D

func before_each() -> void:
	run = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(30)

func _bring(c: Creature, metres: float) -> void:
	var pd: Vector3 = run.planet.to_local(run.player.global_position).normalized()
	c.teleport_to(pd.rotated(SphereMath.basis_from_up(pd).x, metres / run.planet.data.radius))

func test_spawned_away_from_base_and_posts() -> void:
	var d: PlanetData = run.planet.data
	assert_eq(run.creatures.size(), PlanetGenerator.BIOMES["prado"].creatures)
	for c: Creature in run.creatures:
		assert_gte(d.arc_m(c.dir, d.outpost_dir), run.CREATURE_MIN_BASE_M)
		for p in d.posts:
			assert_gte(d.arc_m(c.dir, p), run.CREATURE_MIN_POST_M)

func test_creatures_stay_on_the_surface_while_moving() -> void:
	var c: Creature = run.creatures[0]
	_bring(c, 40.0) # perto o suficiente para estar acordada, longe para não perseguir
	await wait_seconds(2.0)
	var d: PlanetData = run.planet.data
	var local: Vector3 = run.planet.to_local(c.global_position)
	assert_almost_eq(local.length(), d.radius + d.height_at(local.normalized()), 0.05)

func test_chases_and_attacks_nearby_player() -> void:
	var c: Creature = run.creatures[0]
	watch_signals(c)
	_bring(c, 5.0)
	await wait_seconds(4.0)
	assert_signal_emitted(c, "attacked", "devia ter atacado o jogador")
	assert_lt(run.vitals.health, PlayerVitals.MAX_HEALTH, "o ataque tira vida")

func test_steal_touch_drop_and_recover() -> void:
	var dc: DeliveryController = run.deliveries
	var o: DeliveryOrder = dc.session.offers[0]
	dc.accept(o)
	dc.session.pick_up()
	var c: Creature = run.creatures[0]
	c.steal_chance = 1.0
	_bring(c, 4.0)
	for i in 300:
		await wait_physics_frames(1)
		if o.state == DeliveryOrder.State.STOLEN:
			break
	assert_eq(o.state, DeliveryOrder.State.STOLEN, "a criatura devia ter roubado a caixa")
	assert_true(c.carrying)
	# Tocar no ladrão: larga a caixa.
	run.player.place_at(c.global_position + (c.global_position - run.planet.global_position).normalized() * 0.5)
	await wait_physics_frames(5)
	assert_false(c.carrying, "ao tocar devia largar a caixa")
	assert_true(o.state in [DeliveryOrder.State.DROPPED, DeliveryOrder.State.CARRYING])
	# A caixa cai junto ao jogador: apanha-a logo (ou ao chegar ao sítio).
	if o.state == DeliveryOrder.State.DROPPED:
		run.player.place_at(o.drop_position)
		await wait_physics_frames(5)
	assert_eq(o.state, DeliveryOrder.State.CARRYING, "devia ter recuperado a caixa")

func test_thief_drops_crate_by_itself_after_a_while() -> void:
	var dc: DeliveryController = run.deliveries
	var o: DeliveryOrder = dc.session.offers[0]
	dc.accept(o)
	dc.session.pick_up()
	var c: Creature = run.creatures[0]
	_bring(c, 40.0)
	dc.session.steal()
	c.take_crate()
	dc.thief = c
	c._carry_timer = 0.3
	await wait_seconds(0.6)
	assert_eq(o.state, DeliveryOrder.State.DROPPED, "devia largar a caixa sozinha")

func test_fast_rover_knocks_creatures() -> void:
	run.enter_rover()
	var c: Creature = run.creatures[0]
	var rp: Vector3 = run.planet.to_local(run.rover.global_position).normalized()
	c.teleport_to(rp)
	run.rover.linear_velocity = run.rover.forward() * 10.0
	run._check_rams()
	assert_eq(c.mode, Creature.Mode.KNOCKED)
