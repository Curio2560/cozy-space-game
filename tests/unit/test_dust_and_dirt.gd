extends GutTest
## Fumo das rodas, dano do rover por velocidade, encontrões e manchas de terra.

var run: Node3D

func before_each() -> void:
	run = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(60)

func after_each() -> void:
	Input.action_release("move_forward")

func test_driving_raises_dust_and_standing_still_does_not() -> void:
	assert_false(run.dust.emitting)
	run.enter_rover()
	Input.action_press("move_forward", 1.0)
	await wait_physics_frames(90)
	assert_true(run.dust.emitting, "devia sair fumo das rodas a andar")
	Input.action_release("move_forward")

func test_impact_damage_scales_with_speed() -> void:
	var r: Rover = run.rover
	assert_eq(r.impact_to_damage(4.0), 0.0, "impactos lentos não fazem dano")
	assert_gt(r.impact_to_damage(12.0), r.impact_to_damage(8.0))
	assert_gt(r.impact_to_damage(20.0), r.impact_to_damage(12.0))
	assert_eq(r.impact_to_damage(200.0), r.max_impact_damage)

func test_creature_hits_do_not_wreck_the_rover() -> void:
	run.enter_rover()
	run.teleport(run.planet.data.lair_dir)
	await wait_physics_frames(60)
	var c: Creature = run.creatures[0]
	for i in 6:
		run._on_creature_attack(c)
		await wait_physics_frames(40)
	assert_true(run.rover.alive, "6 golpes de criatura não deviam destruir o rover")
	assert_gt(run.rover.health, run.rover.max_health * 0.5)

func test_creature_push_does_not_launch_player() -> void:
	run.teleport(run.planet.data.lair_dir)
	for i in 60:
		await wait_physics_frames(1)
		if run.player.is_on_floor():
			break
	var c: Creature = run.creatures[0]
	run._on_creature_attack(c)
	var peak := 0.0
	var d: PlanetData = run.planet.data
	for i in 40:
		await wait_physics_frames(1)
		var local: Vector3 = run.planet.to_local(run.player.global_position)
		peak = maxf(peak, local.length() - (d.radius + d.height_at(local.normalized())))
	assert_lt(peak, 0.6, "o encontrão não devia atirar o astronauta ao ar (subiu %.2f m)" % peak)

func test_dirt_patches_off_road_and_nothing_grows_on_them() -> void:
	var d: PlanetData = run.planet.data
	assert_gt(d.dirt_patches.size(), 60)
	for p in d.placements:
		for patch in d.dirt_patches:
			assert_gt(d.arc_m(p.dir, patch.dir), float(patch.radius) * 0.9, "%s em cima de uma mancha de terra" % p.kind)
	assert_not_null(run.planet.dirt_mesh)

func test_houses_face_the_road() -> void:
	var d: PlanetData = run.planet.data
	for i in d.posts.size():
		var house: Node3D = run.planet.get_node("Post%d" % i)
		var fwd := house.global_basis.z.normalized()
		var to_door: Vector3 = run.planet.to_global(d.surface_point(d.post_doors[i])) - house.global_position
		assert_gt(fwd.dot(to_door.normalized()), 0.9, "a casa %d devia estar virada para a estrada" % i)
