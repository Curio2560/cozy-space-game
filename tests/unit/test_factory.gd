extends GutTest
## Fábrica de peças (#58): bloqueada sem pesquisa, produz peças gastando minério e cristal.

func _w() -> Wallet:
	var w := Wallet.new()
	w.add(Wallet.CREDITS, 2000)
	w.add(Wallet.CRYSTAL, 10)
	w.add(Wallet.ORE, 10)
	return w

func test_locked_without_research() -> void:
	var o := Outpost.new()
	var w := _w()
	assert_false(o.build(0, "factory", w))
	assert_eq(w.credits(), 2000, "nada gasto")
	o.locked["factory"] = false
	assert_true(o.build(0, "factory", w))

func test_produces_parts_from_ore_and_crystal() -> void:
	var o := Outpost.new()
	var w := _w()
	o.locked["factory"] = false
	o.build(0, "solar", w)
	o.build(1, "factory", w)
	var crystal := w.amount(Wallet.CRYSTAL)
	o.tick(Outpost.BUILDINGS.factory.period * 2.0 + 0.1, w)
	assert_eq(int(o.slots[1].stored), 2)
	assert_eq(w.amount(Wallet.ORE), 10 - 4)
	assert_eq(w.amount(Wallet.CRYSTAL), crystal - 2)
	assert_eq(o.collect(1, w), 2)
	assert_eq(w.amount(Wallet.PARTS), 2)

func test_waits_without_materials() -> void:
	var o := Outpost.new()
	var w := Wallet.new()
	w.add(Wallet.CREDITS, 2000)
	w.add(Wallet.CRYSTAL, 3)
	o.locked["factory"] = false
	o.build(0, "factory", w)
	o.tick(500.0, w)
	assert_eq(int(o.slots[0].stored), 0, "sem minério não produz")

func test_research_unlocks_in_game() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	assert_true(run.outpost.state.is_locked("factory"))
	run.wallet.add(Wallet.DATA, 50)
	assert_true(run.buy_research("factory"))
	assert_false(run.outpost.state.is_locked("factory"))
	run.wallet.add(Wallet.CREDITS, 1000)
	run.wallet.add(Wallet.CRYSTAL, 5)
	assert_true(run.outpost.build(0, "factory"))
