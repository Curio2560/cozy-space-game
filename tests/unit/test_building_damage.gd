extends GutTest
## Vida dos edifícios (#41): dano, desligado a 0 (sem produção nem energia), reparação com
## minério (parcial se faltar), save; no jogo as criaturas estragam e passam ao seguinte.

func _w(credits := 2000, ore := 0) -> Wallet:
	var w := Wallet.new()
	w.add(Wallet.CREDITS, credits)
	if ore > 0:
		w.add(Wallet.ORE, ore)
	return w

func test_damage_breaks_at_zero_and_stops_production_and_energy() -> void:
	var o := Outpost.new()
	var w := _w()
	o.build(0, "solar", w)
	o.build(1, "research", w)
	assert_eq(o.energy_supply(), 3)
	watch_signals(o)
	assert_false(o.damage(1, 40.0))
	assert_true(o.is_damaged(1))
	assert_false(o.is_broken(1))
	assert_true(o.damage(1, 999.0))
	assert_signal_emitted_with_parameters(o, "broke", [1])
	assert_true(o.is_broken(1))
	assert_eq(o.energy_demand(), 0, "desligado não gasta")
	o.tick(600.0, w)
	assert_eq(int(o.slots[1].stored), 0, "desligado não produz")
	assert_false(o.damage(1, 10.0), "já está desligado")
	o.damage(0, 999.0)
	assert_eq(o.energy_supply(), 0, "painel desligado não dá energia")

func test_repair_costs_ore_and_can_be_partial() -> void:
	var o := Outpost.new()
	var w := _w(2000, 4)
	o.build(0, "miner", w)
	o.damage(0, Outpost.MAX_HP)
	assert_eq(o.repair_cost(0), 10)
	assert_eq(o.repair(0, w), 4, "só havia 4")
	assert_almost_eq(o.hp(0), 40.0, 0.01)
	assert_false(o.is_broken(0), "com alguma vida volta a funcionar")
	assert_eq(o.repair(0, w), 0, "sem minério")
	w.add(Wallet.ORE, 50)
	assert_eq(o.repair_all(w), 6)
	assert_eq(o.hp(0), Outpost.MAX_HP)
	assert_eq(w.amount(Wallet.ORE), 44)

func test_turret_has_more_hp_and_broken_turret_is_not_listed_as_working() -> void:
	var o := Outpost.new()
	var w := _w()
	o.build(0, "turret", w)
	assert_eq(o.hp(0), Outpost.TURRET_HP)
	o.damage(0, 999.0)
	assert_false(o.is_working(0))

func test_hp_saved() -> void:
	var o := Outpost.new()
	var w := _w()
	o.build(3, "storage", w)
	o.damage(3, 35.0)
	var p := Outpost.new()
	p.from_dict(JSON.parse_string(JSON.stringify(o.to_dict())))
	assert_almost_eq(p.hp(3), 65.0, 0.01)
	var old := Outpost.new() # save antigo sem "hp": vida cheia
	old.from_dict({"slot_count": 6, "slots": [{"kind": "miner", "stored": 0, "progress": 0.0}]})
	assert_eq(old.hp(0), Outpost.MAX_HP)

func test_raiders_damage_then_move_to_next_building() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(3)
	run.wallet.add(Wallet.CREDITS, 1000)
	run.outpost.build(0, "solar")
	run.outpost.build(1, "solar")
	run.cycle.skip_to_night()
	run.defense.waves.launch_next()
	var c: Creature = run.defense.raiders[0]
	run.outpost.state.damage(0, Outpost.MAX_HP - 1.0)
	var d: PlanetData = run.planet.data
	c.teleport_to(d.outpost_slots[0])
	await wait_physics_frames(120)
	assert_true(run.outpost.state.is_broken(0), "a criatura desligou o painel")
	assert_gt(run.defense.night_damage, 0.0)
	assert_eq(run.defense.night_broken, 1)
	assert_eq(run.defense._target_for(c)[2], 1, "passa ao edifício seguinte")
	run.wallet.add(Wallet.ORE, 20)
	assert_gt(run.outpost.repair(0), 0)
	assert_false(run.outpost.state.is_broken(0))
