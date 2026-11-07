extends GutTest
## Save (#30): ida e volta, versão, apagar, autosave só quando ativo.

func before_each() -> void:
	SaveGame.path = "user://test_save.json"
	SaveGame.erase()

func after_each() -> void:
	SaveGame.erase()
	SaveGame.path = SaveGame.DEFAULT_PATH
	SaveGame.active = false

func test_write_and_read_round_trip() -> void:
	assert_true(SaveGame.write({"planet": {"seed": 42, "biome": "acido"}, "wallet": {"credits": 120}}))
	var s := SaveGame.read()
	assert_eq(int(s.planet.seed), 42)
	assert_eq(s.planet.biome, "acido")
	assert_eq(int(s.wallet.credits), 120)
	assert_eq(int(s.version), SaveGame.VERSION)

func test_other_version_is_ignored() -> void:
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 999, "planet": {"seed": 1}}))
	f.close()
	assert_eq(SaveGame.read(), {})

func test_broken_file_is_ignored() -> void:
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string("{isto não é json")
	f.close()
	assert_eq(SaveGame.read(), {})

func test_erase() -> void:
	SaveGame.write({"a": 1})
	assert_true(SaveGame.exists())
	SaveGame.erase()
	assert_false(SaveGame.exists())

func test_wallet_round_trip_never_negative() -> void:
	var w := Wallet.new()
	w.add(Wallet.CREDITS, 50)
	w.add(Wallet.ORE, 3)
	var w2 := Wallet.new()
	w2.from_dict(w.to_dict())
	assert_eq(w2.credits(), 50)
	assert_eq(w2.amount(Wallet.ORE), 3)
	w2.from_dict({"credits": -5})
	assert_eq(w2.credits(), 0)

func _run() -> Node3D:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	return run

func test_game_state_survives_save_and_load() -> void:
	SaveGame.active = true
	var run := _run()
	await wait_physics_frames(5)
	run.wallet.add(Wallet.CREDITS, 777)
	run.deliveries.session.colonists[1].reputation = 5
	run.deliveries.session.keycards = 2
	var seed: int = run.seed_value
	run.autosave()
	run.queue_free()
	await wait_physics_frames(2)
	var again := _run()
	await wait_physics_frames(5)
	assert_eq(again.seed_value, seed, "mesmo planeta")
	assert_eq(again.wallet.credits(), 777)
	assert_eq(again.deliveries.session.colonists[1].reputation, 5)
	assert_eq(again.deliveries.session.keycards, 2)

func test_inactive_save_is_not_touched() -> void:
	SaveGame.active = false
	var run := _run()
	await wait_physics_frames(5)
	run.autosave()
	assert_false(SaveGame.exists())

func test_new_game_erases_save_and_resets_wallet() -> void:
	SaveGame.active = true
	var run := _run()
	await wait_physics_frames(5)
	run.wallet.add(Wallet.CREDITS, 300)
	run.autosave()
	run.new_game()
	await wait_physics_frames(2)
	assert_eq(run.wallet.credits(), 0)
	var s := SaveGame.read()
	assert_eq(int(s.wallet.credits), 0, "o save novo começa do zero")
