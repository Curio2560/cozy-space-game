extends GutTest
## Melhorias (#34): compra atómica, níveis, efeitos no rover e nas entregas, slots, save.

func test_buy_levels_and_max() -> void:
	var w := Wallet.new()
	w.add(Wallet.CREDITS, 10000)
	w.add(Wallet.CRYSTAL, 5)
	var u := Upgrades.new()
	assert_true(u.buy("speed", w))
	assert_eq(w.credits(), 10000 - 150)
	assert_true(u.buy("speed", w))
	assert_true(u.buy("speed", w), "nível 3 com cristal")
	assert_eq(w.amount(Wallet.CRYSTAL), 0)
	assert_false(u.buy("speed", w), "já no máximo")
	assert_eq(u.next_cost("speed"), {})
	assert_almost_eq(u.speed_factor(), 1.36, 0.001)

func test_cannot_buy_without_money() -> void:
	var u := Upgrades.new()
	assert_false(u.buy("shield", Wallet.new()))
	assert_eq(u.level("shield"), 0)

func test_effects() -> void:
	var u := Upgrades.new()
	u.levels.shield = 2
	u.levels.cargo = 1
	u.levels.suspension = 3
	assert_almost_eq(u.shield_factor(), 0.6, 0.001)
	assert_almost_eq(u.cargo_factor(), 0.8, 0.001)
	assert_almost_eq(u.suspension_bonus(), 4.5, 0.001)

func test_save_round_trip() -> void:
	var u := Upgrades.new()
	u.levels.cargo = 2
	u.levels.slots = 1
	var v := Upgrades.new()
	v.from_dict(JSON.parse_string(JSON.stringify(u.to_dict())))
	assert_eq(v.level("cargo"), 2)
	assert_eq(v.level("slots"), 1)

func _run() -> Node3D:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	return run

func test_in_game_upgrades_apply_to_rover_and_slots() -> void:
	var run := _run()
	await wait_physics_frames(5)
	run.wallet.add(Wallet.CREDITS, 5000)
	assert_true(run.buy_upgrade("shield"))
	assert_almost_eq(run.rover.damage_factor, 0.8, 0.001)
	var before: float = run.rover.health
	run.rover.take_damage(10.0)
	assert_almost_eq(run.rover.health, before - 8.0, 0.01)
	assert_true(run.buy_upgrade("cargo"))
	assert_almost_eq(run.deliveries.session.cargo_factor, 0.8, 0.001)
	assert_true(run.buy_upgrade("slots"))
	assert_eq(run.outpost.slot_total(), Outpost.START_SLOTS + 2)
	assert_not_null(run.planet.get_node_or_null("Slot7"))
