extends GutTest
## Bioma de gelo (#60): gera, o rover escorrega, o frio tira vida longe do posto e do rover,
## o fato térmico corta para metade, entra na galáxia.

func test_generates_with_snow_props() -> void:
	var d := PlanetGenerator.generate(11, "gelo")
	assert_gt(d.placements.size(), 100)
	assert_true(d.placements.any(func(p: Dictionary) -> bool: return str(p.kind).contains("Snow")))
	assert_true(d.rivers.is_empty(), "sem rios no gelo")

func test_ice_in_galaxy_choices() -> void:
	var g := Galaxy.new()
	var seen := {}
	for s in 40:
		g.seed_value = s
		g.index = 2
		for o in g.next_options():
			seen[o.biome] = true
	assert_true(seen.has("gelo"), "o gelo aparece nas escolhas depois da lava")
	assert_eq(BossRules.model_for("gelo", 3), "big/Yeti")

func test_rover_grip_and_cold_in_game() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	assert_eq(run.rover.grip_factor, 1.0)
	assert_eq(run.cold_rate(), 0.0, "sem frio no prado")
	run.biome = "gelo"
	run.start(11)
	await wait_physics_frames(3)
	assert_lt(run.rover.grip_factor, 1.0, "o rover escorrega")
	var d: PlanetData = run.planet.data
	assert_eq(run.cold_rate(), 0.0, "perto do posto está quente")
	run.teleport(d.toward_point(d.outpost_dir, d.posts[0], 45.0))
	run.rover.place_at(run.planet.to_global(d.surface_point(d.lair_dir) + d.lair_dir * 1.0), run.rover.forward())
	await wait_physics_frames(2)
	var cold: float = run.cold_rate()
	assert_gt(cold, 0.0, "longe do posto e do rover tira vida")
	run.wallet.add(Wallet.DATA, 100)
	run.buy_research("rover_o2")
	run.buy_research("cold_suit")
	assert_almost_eq(run.cold_rate(), cold * 0.5, 0.001, "fato térmico")
	var hp: float = run.vitals.health
	await wait_physics_frames(60)
	assert_lt(run.vitals.health, hp)
