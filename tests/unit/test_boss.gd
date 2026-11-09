extends GutTest
## Boss (#46/#47): arena, porta só com KeyCards, fases, golpes avisados, invocações,
## derrota (KeyCards ficam) e vitória.

func test_rules() -> void:
	assert_eq(BossRules.phase(1.0), 1)
	assert_eq(BossRules.phase(0.5), 2)
	assert_eq(BossRules.phase(0.1), 3)
	assert_gt(BossRules.health(2), BossRules.health(0))
	assert_eq(BossRules.model_for("prado", 0), "big/MushroomKing")
	assert_true(BossRules.model_for("outro", 5) in BossRules.FALLBACK)
	for id in BossRules.MODELS.values() + BossRules.FALLBACK:
		assert_has(CreatureCatalog.ids(), id, "o modelo existe no pack")

func test_arena_is_flat_spot_next_to_lair() -> void:
	var d := PlanetGenerator.generate(7, "prado")
	assert_almost_eq(d.arc_m(d.arena_dir, d.lair_dir), PlanetGenerator.ARENA_OFFSET_M, 1.0)
	assert_gt(d.arc_m(d.arena_dir, d.outpost_dir), d.arc_m(d.lair_dir, d.outpost_dir), "do lado de lá do covil")
	var flat := d.flat_spots.any(func(s: Dictionary) -> bool: return s.dir.is_equal_approx(d.arena_dir))
	assert_true(flat)

func _run() -> Node3D:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	return run

func _at_door(run: Node3D) -> void:
	var d: PlanetData = run.planet.data
	run.teleport(d.toward_point(d.lair_door, d.lair_dir, -1.5))

func test_door_needs_keycards() -> void:
	var run: Node3D = await _run()
	_at_door(run)
	await wait_physics_frames(2)
	assert_true(run.boss_fight.near_door())
	assert_false(run.boss_fight.can_start())
	assert_string_contains(run.boss_fight.hint(), "0")
	run.deliveries.session.keycards = 3
	assert_true(run.boss_fight.can_start())

func _start(run: Node3D) -> void:
	run.deliveries.session.keycards = 3
	_at_door(run)
	await wait_physics_frames(2)
	await run.boss_fight.start()

func test_fight_starts_in_mech_with_clock_stopped() -> void:
	var run: Node3D = await _run()
	await _start(run)
	assert_eq(run.boss_fight.state, BossFight.State.FIGHT)
	assert_true(run.piloting)
	assert_true(run.cycle.paused)
	assert_true(run.defense.suspended)
	var b: Boss = run.boss_fight.boss
	assert_not_null(b)
	var d: PlanetData = run.planet.data
	assert_lt(d.arc_m(b.dir, d.arena_dir), 1.0)
	assert_true(b in run.all_creatures(), "o mech pode mirar o boss")

func test_slam_is_warned_then_hits_mech_inside_circle() -> void:
	var run: Node3D = await _run()
	await _start(run)
	var b: Boss = run.boss_fight.boss
	var md: Vector3 = run.planet.to_local(run.mech.global_position).normalized()
	b._start_attack(md)
	assert_false(b.pending_attack().is_empty(), "há aviso antes do golpe")
	var hp: float = run.mech.health
	b._finish_attack()
	assert_lt(run.mech.health, hp, "dentro do círculo leva dano")
	hp = run.mech.health
	run.boss_fight._on_slam(run.planet.data.lair_dir, BossRules.SLAM_RADIUS, 50.0)
	assert_eq(run.mech.health, hp, "fora do círculo não")

func test_phases_and_summons() -> void:
	var run: Node3D = await _run()
	await _start(run)
	var b: Boss = run.boss_fight.boss
	watch_signals(b)
	b.take_hit(b.max_health * 0.5)
	assert_eq(b.phase, 2)
	assert_signal_emitted_with_parameters(b, "phase_changed", [2])
	run.boss_fight._on_summon(3)
	assert_eq(run.boss_fight.summons.size(), 3)
	b.take_hit(b.max_health * 0.3)
	assert_eq(b.phase, 3)

func test_losing_keeps_keycards_and_returns_to_base() -> void:
	var run: Node3D = await _run()
	await _start(run)
	run.mech.take_damage(1e9)
	await wait_seconds(1.5)
	assert_eq(run.boss_fight.state, BossFight.State.IDLE)
	assert_false(run.piloting)
	assert_eq(run.deliveries.session.keycards, 3)
	assert_false(run.boss_fight.beaten)
	assert_false(run.cycle.paused)
	assert_null(run.boss_fight.boss)

func test_winning() -> void:
	var run: Node3D = await _run()
	await _start(run)
	watch_signals(run.boss_fight)
	run.boss_fight.boss.take_hit(1e9)
	await wait_seconds(3.5)
	assert_signal_emitted(run.boss_fight, "won")
	assert_true(run.boss_fight.beaten)
	assert_false(run.piloting)
	assert_false(run.boss_fight.can_start(), "não se luta outra vez")
