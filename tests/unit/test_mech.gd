extends GutTest
## Mech (#39): arma sem limite, projéteis, mira no mais perto, entrar/sair à noite, tiros matam.

func test_gun_fires_at_rate_forever() -> void:
	# Munições infinitas: 30 s a disparar sem parar e nunca bloqueia.
	var g := MechGun.new()
	var shots := 0
	for i in 60 * 30:
		shots += g.tick(1.0 / 60.0, true)
	assert_almost_eq(float(shots) / 30.0, 1.0 / MechGun.INTERVAL, 1.0, "cadência constante")
	assert_eq(g.tick(MechGun.INTERVAL, true), 1, "continua a disparar")

func test_gun_does_not_fire_without_target_or_trigger() -> void:
	var g := MechGun.new()
	assert_eq(g.tick(0.5, true, false), 0)
	assert_eq(g.tick(0.5, false, true), 0)

func test_nearest_in_range() -> void:
	var ps := [Vector3(30, 0, 0), Vector3(5, 0, 0), Vector3(0, 3, 0)]
	assert_eq(MechGun.nearest(Vector3.ZERO, ps), 2)
	assert_eq(MechGun.nearest(Vector3.ZERO, [Vector3(99, 0, 0)]), -1)

func _run() -> Node3D:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	return run

func _go_to_mech(run: Node3D) -> void:
	var m: Mech = run.mech
	run.player.place_at(m.global_position + m.facing * 3.0 + m.up() * 0.5)

func test_mech_only_at_night_and_shoots_raiders() -> void:
	var run: Node3D = await _run()
	assert_eq(run.mech.crew, run.crew.active)
	_go_to_mech(run)
	await wait_physics_frames(2)
	assert_false(run.can_enter_mech(), "de dia não")
	assert_true(run.near_mech_by_day())
	run.cycle.skip_to_night()
	_go_to_mech(run)
	await wait_physics_frames(2)
	assert_true(run.can_enter_mech())
	run.enter_mech()
	assert_true(run.piloting)
	assert_eq(run.carrier_node(), run.mech)
	run.defense.waves.launch_next()
	var c: Creature = run.defense.raiders[0]
	var m: Mech = run.mech
	var pd: Vector3 = run.planet.to_local(m.global_position).normalized()
	c.teleport_to(pd.rotated(SphereMath.basis_from_up(pd).x, 8.0 / run.planet.data.radius))
	await wait_physics_frames(2)
	assert_eq(m.find_target(), c)
	var hp := c.health
	Input.action_press("jump")
	await wait_physics_frames(1)
	assert_gt(m.projectiles.active_count(), 0, "sai um projétil")
	assert_eq(c.health, hp, "o projétil ainda não chegou: não é instantâneo")
	await wait_physics_frames(40)
	Input.action_release("jump")
	assert_true(c.dead or c.health < hp, "os projéteis acertam")
	run.exit_mech()
	assert_false(run.piloting)
	assert_true(run.player.visible)

func test_broken_mech_ejects_and_morning_repairs() -> void:
	var run: Node3D = await _run()
	run.cycle.skip_to_night()
	_go_to_mech(run)
	await wait_physics_frames(2)
	run.enter_mech()
	run.mech.take_damage(9999.0)
	assert_false(run.piloting, "sai quando o mech avaria")
	assert_false(run.can_enter_mech())
	run.cycle.skip_to_morning()
	assert_eq(run.mech.health, Mech.MAX_HEALTH)

func test_walk_animation_matches_ground_speed() -> void:
	# Os pés não podem escorregar: a cadência da animação acompanha a velocidade real.
	var run: Node3D = await _run()
	run.cycle.skip_to_night()
	_go_to_mech(run)
	await wait_physics_frames(2)
	run.enter_mech()
	Input.action_press("move_forward", 1.0)
	await wait_physics_frames(60)
	var m: Mech = run.mech
	var u := m.up()
	var spd := (m.velocity - u * m.velocity.dot(u)).length()
	Input.action_release("move_forward")
	assert_eq(m._anim_name, "Walk", "anda com a animação de andar (a Run é para ~14 m/s)")
	var feet: float = Mech.WALK_ANIM_SPEED * m._anim.speed_scale
	assert_almost_eq(feet / spd, 1.0, 0.15, "pés a acompanhar o chão")
