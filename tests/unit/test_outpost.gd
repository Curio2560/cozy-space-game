extends GutTest
## Regras do posto (#32): construir, energia, produção, armazém, recolha, save.

var w: Wallet
var o: Outpost

func before_each() -> void:
	w = Wallet.new()
	w.add(Wallet.CREDITS, 5000)
	o = Outpost.new()

func test_build_pays_and_fills_slot_once() -> void:
	assert_true(o.build(0, "miner", w))
	assert_eq(w.credits(), 5000 - 120)
	assert_false(o.build(0, "solar", w), "slot ocupado")
	assert_false(o.build(Outpost.START_SLOTS, "solar", w), "slot ainda fechado")

func test_cannot_build_without_money() -> void:
	var poor := Wallet.new()
	assert_false(o.build(0, "miner", poor))
	assert_true(o.is_empty(0))

func test_miner_produces_one_ore_every_20s() -> void:
	o.build(0, "miner", w)
	o.build(1, "solar", w)
	o.tick(59.0, w)
	assert_eq(o.slots[0].stored, 2)
	o.tick(1.0, w)
	assert_eq(o.slots[0].stored, 3)

func test_without_enough_power_production_halves() -> void:
	o.build(0, "miner", w) # gasta 1, sem painel: 0 >= 1 é falso
	assert_eq(o.power_factor(), Outpost.LOW_POWER)
	o.tick(40.0, w)
	assert_eq(o.slots[0].stored, 1)

func test_solar_powers_three_buildings() -> void:
	o.build(0, "solar", w)
	for i in range(1, 4):
		o.build(i, "miner", w)
	assert_eq(o.power_factor(), 1.0)
	o.build(4, "research", w)
	assert_eq(o.power_factor(), Outpost.LOW_POWER, "4 a gastar, só 3 de energia")

func test_lab_turns_two_ore_into_crystal_and_waits_without_ore() -> void:
	w.add(Wallet.ORE, 10) # custo do laboratório
	assert_true(o.build(0, "lab", w))
	assert_eq(w.amount(Wallet.ORE), 0)
	o.build(1, "solar", w)
	w.add(Wallet.ORE, 3)
	o.tick(80.0, w)
	assert_eq(o.slots[0].stored, 1, "só havia minério para 1")
	assert_eq(w.amount(Wallet.ORE), 1)
	w.add(Wallet.ORE, 2)
	o.tick(0.1, w)
	assert_eq(o.slots[0].stored, 2, "estava pronto à espera de minério")

func test_storage_caps_and_bonus() -> void:
	o.build(0, "miner", w)
	o.build(1, "solar", w)
	o.tick(20.0 * 30, w)
	assert_eq(o.slots[0].stored, Outpost.CAPACITY)
	o.build(2, "storage", w)
	o.tick(20.0 * 30, w)
	assert_eq(o.slots[0].stored, Outpost.CAPACITY + Outpost.STORAGE_BONUS)

func test_collect_moves_to_wallet() -> void:
	o.build(0, "miner", w)
	o.build(1, "solar", w)
	o.tick(100.0, w)
	assert_eq(o.collect_all(w), 5)
	assert_eq(w.amount(Wallet.ORE), 5)
	assert_eq(o.slots[0].stored, 0)

func test_extra_slots_up_to_ten() -> void:
	assert_true(o.add_slots())
	assert_eq(o.slot_count, 8)
	o.add_slots()
	assert_false(o.add_slots())
	assert_eq(o.slot_count, Outpost.MAX_SLOTS)

func test_save_round_trip() -> void:
	o.build(0, "miner", w)
	o.add_slots()
	o.tick(45.0, w)
	var o2 := Outpost.new()
	o2.from_dict(JSON.parse_string(JSON.stringify(o.to_dict())))
	assert_eq(o2.slot_count, 8)
	assert_eq(o2.slots[0].kind, "miner")
	assert_eq(o2.slots[0].stored, o.slots[0].stored)
