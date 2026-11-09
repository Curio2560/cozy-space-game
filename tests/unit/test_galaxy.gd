extends GutTest
## Galáxia (#49/#50): caminho fixo e escolhas, dificuldade, viagem, o que passa, save.

func test_fixed_path_then_two_choices() -> void:
	var g := Galaxy.new()
	g.seed_value = 5
	assert_eq(g.first().biome, "prado")
	var o: Array = g.next_options()
	assert_eq(o.size(), 1)
	assert_eq(o[0].biome, "acido")
	g.advance(o[0])
	assert_eq(g.next_options()[0].biome, "lava")
	g.advance(g.next_options()[0])
	var ch: Array = g.next_options()
	assert_eq(ch.size(), 2)
	assert_ne(ch[0].biome, ch[1].biome)
	assert_ne(ch[0].seed, ch[1].seed)
	assert_eq(g.next_options(), ch, "determinista")
	assert_eq(g.night_offset(), 2 * Galaxy.NIGHTS_PER_PLANET)

func test_save_round_trip() -> void:
	var g := Galaxy.new()
	g.seed_value = 9
	g.index = 4
	var h := Galaxy.new()
	h.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	assert_eq(h.index, 4)
	assert_eq(h.next_options(), g.next_options())

func test_map_skip_and_choice() -> void:
	var m := GalaxyMap.new()
	add_child_autofree(m)
	var g := Galaxy.new()
	g.index = 2
	watch_signals(m)
	m.begin(g, "lava")
	m.skip()
	await wait_process_frames(3)
	assert_signal_not_emitted(m, "finished", "espera pela escolha")
	assert_true(m._choosing)
	m.choose(1)
	m.skip()
	await wait_process_frames(3)
	assert_signal_emitted_with_parameters(m, "finished", [g.next_options()[1]])

func test_travel_to_next_planet_keeps_credits_drops_ore() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	run.wallet.add(Wallet.CREDITS, 777)
	run.wallet.add(Wallet.ORE, 20)
	run.wallet.add(Wallet.DATA, 9)
	run.deliveries.session.keycards = 3
	run.boss_fight.beaten = true
	run.cycle.skip_to_night()
	var credits: int = run.wallet.credits()
	run.arrive(run.galaxy.next_options()[0])
	await wait_physics_frames(3)
	assert_eq(run.biome, "acido")
	assert_eq(run.planet_index, 1)
	assert_eq(run.wallet.credits(), credits)
	assert_eq(run.wallet.amount(Wallet.ORE), 0, "o minério ficou para trás")
	assert_eq(run.wallet.amount(Wallet.DATA), 9, "os dados vêm")
	assert_eq(run.deliveries.session.keycards, 0, "KeyCards são por planeta")
	assert_false(run.boss_fight.beaten)
	assert_eq(run.cycle.day, 1)
	assert_false(run.cycle.is_night())
	run.cycle.skip_to_night()
	assert_eq(run.defense.waves.night, 1 + Galaxy.NIGHTS_PER_PLANET, "+2 noites de dificuldade")
	assert_eq(run.save_state().galaxy.index, 1)
