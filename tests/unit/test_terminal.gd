extends GutTest
## Terminal do posto e venda (#31).

func test_sell_prices_and_atomicity() -> void:
	var w := Wallet.new()
	w.add(Wallet.ORE, 5)
	w.add(Wallet.CRYSTAL, 2)
	assert_eq(Market.sell(w, Wallet.ORE, 2), 2 * 4)
	assert_eq(w.amount(Wallet.ORE), 3)
	assert_eq(Market.sell(w, Wallet.CRYSTAL), 2 * 15, "vender tudo")
	assert_eq(w.amount(Wallet.CRYSTAL), 0)
	assert_eq(Market.sell(w, Wallet.CRYSTAL, 1), 0, "nada para vender")
	assert_eq(w.credits(), 8 + 30)

func test_research_data_is_not_sold() -> void:
	var w := Wallet.new()
	w.add(Wallet.DATA, 3)
	assert_false(Market.can_sell(Wallet.DATA))
	assert_eq(Market.sell(w, Wallet.DATA), 0)
	assert_eq(w.amount(Wallet.DATA), 3)

func test_terminal_opens_next_to_it_and_sells() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(30)
	var op: OutpostController = run.outpost
	assert_false(op.terminal_position() == Vector3.INF, "terminal colocado")
	var p: Vector3 = op.terminal_position()
	var up: Vector3 = (p - run.planet.global_position).normalized()
	run.player.place_at(p + up * 1.0 + (run.planet.global_basis * SphereMath.basis_from_up(run.planet.to_local(p).normalized()).z) * 1.5)
	await wait_physics_frames(20)
	assert_true(op.near_terminal(), "o jogador devia estar junto ao terminal")
	assert_ne(op.hint(), "")
	op.open_menu()
	assert_true(op.menu.visible)
	run.wallet.add(Wallet.ORE, 4)
	op.menu._sell(Wallet.ORE, -1)
	assert_eq(run.wallet.credits(), 16)
	op.close_menu()
	assert_false(op.menu_open)
	assert_true(run.player.controllable)

func test_hud_shows_resources() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(5)
	run.wallet.add(Wallet.ORE, 3)
	await wait_physics_frames(2)
	assert_string_contains(run.deliveries.hud.resources_label.text, "3")
