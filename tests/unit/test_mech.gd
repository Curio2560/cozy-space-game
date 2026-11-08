extends GutTest
## Mech (#39): arma com aquecimento, mira no mais perto, entrar/sair à noite, tiros matam.

func test_gun_fires_at_rate_and_overheats() -> void:
	var g := MechGun.new()
	var shots := 0
	for i in 60: # 1 s a disparar
		shots += g.tick(1.0 / 60.0, true)
	assert_almost_eq(shots, int(1.0 / MechGun.INTERVAL), 2)
	assert_false(g.locked, "1 s de tiro ainda não sobreaquece")
	assert_gt(g.heat, 0.0)
	watch_signals(g)
	for i in 600:
		g.tick(1.0 / 60.0, true)
		if g.locked:
			break
	assert_true(g.locked, "disparar sem parar sobreaquece")
	assert_signal_emitted(g, "overheated")
	assert_eq(g.tick(0.2, true), 0, "bloqueada não dispara")

func test_gun_cools_and_unlocks() -> void:
	var g := MechGun.new()
	g.heat = MechGun.MAX_HEAT
	g.locked = true
	watch_signals(g)
	for i in 240:
		g.tick(1.0 / 60.0, false)
	assert_false(g.locked)
	assert_signal_emitted(g, "cooled")
	assert_lt(g.heat, MechGun.RESUME)

func test_gun_does_not_fire_or_heat_without_target() -> void:
	var g := MechGun.new()
	assert_eq(g.tick(0.5, true, false), 0)
	assert_eq(g.heat, 0.0)

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
	await wait_physics_frames(30)
	Input.action_release("jump")
	assert_true(c.dead or c.health < hp, "os tiros acertam")
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
