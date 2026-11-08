extends GutTest
## Quinta (#33): talhões, culturas, colher, save; encomendas perecíveis com colheitas.

var w: Wallet
var f: Farm

func before_each() -> void:
	w = Wallet.new()
	w.add(Wallet.CREDITS, 100)
	f = Farm.new()

func test_plot_states_and_times() -> void:
	assert_eq(f.state(0), "empty")
	assert_true(f.plant(0, "fast", w))
	assert_eq(w.credits(), 100 - 2, "paga a semente")
	assert_eq(f.state(0), "growing")
	f.tick(119.0)
	assert_eq(f.state(0), "growing")
	f.tick(1.0)
	assert_eq(f.state(0), "ready")
	assert_false(f.plant(0, "mid", w), "ocupado")

func test_slow_crop_takes_seven_minutes_and_pays_more() -> void:
	f.plant(1, "slow", w)
	f.tick(419.0)
	assert_eq(f.state(1), "growing")
	f.tick(1.0)
	assert_eq(f.harvest(1, w), Farm.YIELD)
	assert_eq(w.amount(Wallet.CROP_SLOW), Farm.YIELD)
	assert_gt(Market.price(Wallet.CROP_SLOW), Market.price(Wallet.CROP_MID))
	assert_gt(Market.price(Wallet.CROP_MID), Market.price(Wallet.CROP_FAST))
	assert_eq(f.state(1), "empty")

func test_cannot_harvest_before_ready_or_plant_without_money() -> void:
	f.plant(0, "mid", w)
	assert_eq(f.harvest(0, w), 0)
	var poor := Wallet.new()
	assert_false(f.plant(1, "fast", poor))

func test_growth_speed_bonus() -> void:
	f.growth_speed = 2.0
	f.plant(0, "fast", w)
	f.tick(60.0)
	assert_eq(f.state(0), "ready")

func test_save_round_trip() -> void:
	f.plant(2, "mid", w)
	f.tick(100.0)
	var g := Farm.new()
	g.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	assert_eq(g.plots[2].crop, "mid")
	assert_almost_eq(float(g.plots[2].t), 100.0, 0.01)

func test_crop_orders_need_and_use_a_crop() -> void:
	var s := DeliverySession.new(w, [[0, 100, 100], [100, 0, 100], [100, 100, 0]], 3)
	var o := s.make_order(0, 1, "perishable")
	o.crop = Wallet.CROP_MID
	s.offers.append(o)
	assert_false(s.can_accept(o), "sem colheita na carteira")
	w.add(Wallet.CROP_MID, 2)
	assert_true(s.accept(o))
	assert_eq(w.amount(Wallet.CROP_MID), 1, "a colheita vai na encomenda")

func test_some_perishable_orders_ask_for_crops() -> void:
	var s := DeliverySession.new(w, [[0, 100, 100], [100, 0, 100], [100, 100, 0]], 5)
	var with_crop := 0
	for i in 60:
		if s.make_order(0, 1, "perishable").crop != "":
			with_crop += 1
	assert_between(with_crop, 10, 50)

func test_farm_in_game_plant_and_harvest() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(10)
	var fc: FarmController = run.farm
	assert_eq(fc.plot_total(), Farm.PLOTS)
	assert_not_null(run.planet.get_node_or_null("Plot0"))
	run.wallet.add(Wallet.CREDITS, 50)
	var d: PlanetData = run.planet.data
	run.teleport(d.toward_point(d.farm_plots[0], d.outpost_dir, 1.5))
	await wait_physics_frames(10)
	assert_eq(fc.nearest_plot(), 0)
	assert_true(fc.plant(0, "fast"))
	fc.farm.tick(130.0)
	assert_eq(fc.harvest(0), Farm.YIELD)
	assert_eq(run.wallet.amount(Wallet.CROP_FAST), Farm.YIELD)
