extends GutTest
## Vagas da noite (#38): tamanhos, horários, mortes, vagas vencidas; criaturas a atacar o posto.

func test_wave_sizes_grow_each_night_and_first_is_easier() -> void:
	assert_lt(NightWaves.wave_size(1, 1), NightWaves.wave_size(2, 1), "a 1.ª noite é mais fácil")
	assert_lt(NightWaves.wave_size(2, 1), NightWaves.wave_size(2, 3), "a 3.ª vaga é maior")
	assert_lt(NightWaves.wave_size(3, 2), NightWaves.wave_size(5, 2))
	assert_eq(NightWaves.wave_size(99, 3), NightWaves.MAX_PER_WAVE)
	assert_gt(NightWaves.creature_health(4), NightWaves.creature_health(1))

func test_three_waves_on_schedule() -> void:
	var w := NightWaves.new()
	watch_signals(w)
	w.start_night(1)
	w.tick(NightWaves.WAVE_AT[0] - 0.5)
	assert_signal_not_emitted(w, "spawn")
	w.tick(1.0)
	assert_eq(w.wave, 1)
	assert_signal_emitted_with_parameters(w, "spawn", [NightWaves.wave_size(1, 1), NightWaves.creature_health(1)])
	w.tick(NightWaves.WAVE_AT[1])
	assert_eq(w.wave, 2, "a 2.ª vaga chega à hora mesmo sem vencer a 1.ª")
	assert_eq(w.alive, NightWaves.wave_size(1, 1) + NightWaves.wave_size(1, 2))
	w.tick(NightWaves.WAVE_AT[2])
	assert_eq(w.wave, 3)
	w.tick(100.0)
	assert_eq(w.wave, 3, "nunca mais de 3")

func test_kills_clear_waves_and_bring_next_sooner() -> void:
	var w := NightWaves.new()
	watch_signals(w)
	w.start_night(2)
	w.launch_next()
	for i in NightWaves.wave_size(2, 1):
		w.killed()
	assert_signal_emitted_with_parameters(w, "wave_cleared", [1])
	assert_eq(w.cleared, 1)
	w.tick(NightWaves.BREAK + 0.1)
	assert_eq(w.wave, 2, "a seguinte chega depois da pausa")

func test_overlapping_waves_all_count_as_cleared() -> void:
	var w := NightWaves.new()
	watch_signals(w)
	w.start_night(1)
	w.launch_next()
	w.launch_next()
	for i in w.alive:
		w.killed()
	assert_signal_emit_count(w, "wave_cleared", 2)
	assert_eq(w.cleared, 2)
	w.launch_next()
	for i in w.alive:
		w.killed()
	assert_true(w.all_cleared())

func test_no_waves_without_night() -> void:
	var w := NightWaves.new()
	w.tick(500.0)
	w.launch_next()
	assert_eq(w.wave, 0)

func _run() -> Node3D:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	return run

func test_night_spawns_raiders_that_go_for_buildings() -> void:
	var run: Node3D = await _run()
	run.wallet.add(Wallet.CREDITS, 1000)
	assert_true(run.outpost.state.build(0, "solar", run.wallet))
	run.outpost.rebuild()
	run.cycle.skip_to_night()
	assert_true(run.defense.waves.active())
	run.defense.waves.launch_next()
	var n: int = run.defense.raiders.size()
	assert_eq(n, NightWaves.wave_size(1, 1))
	var c: Creature = run.defense.raiders[0]
	assert_true(c.raider)
	var d: PlanetData = run.planet.data
	assert_almost_eq(d.arc_m(c.dir, d.outpost_dir), DefenseController.SPAWN_ARC_M, 7.0)
	run.player.place_at(run.player.global_position + Vector3(0, 0, 0)) # jogador longe dos raiders
	var tgt: Array = run.defense._target_for(c)
	assert_eq(tgt[2], 0, "vai ao edifício do slot 0")
	watch_signals(run.defense)
	c.teleport_to(d.outpost_slots[0])
	await wait_physics_frames(90)
	assert_signal_emitted(run.defense, "building_hit")
	assert_true(run.defense.label.visible)

func test_raiders_target_player_when_close_or_no_buildings() -> void:
	var run: Node3D = await _run()
	run.cycle.skip_to_night()
	run.defense.waves.launch_next()
	var c: Creature = run.defense.raiders[0]
	assert_eq(run.defense._target_for(c)[2], "player", "sem edifícios vai ao jogador")
	assert_true(run.creatures.is_empty() or run.creatures[0].night_hostile)

func test_killing_raiders_counts_and_morning_clears() -> void:
	var run: Node3D = await _run()
	run.cycle.skip_to_night()
	run.defense.waves.launch_next()
	var n: int = run.defense.raiders.size()
	run.defense.raiders[0].take_hit(9999.0)
	assert_eq(run.defense.waves.alive, n - 1)
	assert_eq(run.defense.raiders.size(), n - 1)
	run.cycle.skip_to_morning()
	assert_false(run.defense.waves.active())
	assert_eq(run.defense.raiders.size(), 0)
	assert_true(run.creatures.is_empty() or not run.creatures[0].night_hostile)
