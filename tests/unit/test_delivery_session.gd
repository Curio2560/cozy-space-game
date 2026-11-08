extends GutTest

const DIST := [[0.0, 120.0, 90.0], [120.0, 0.0, 130.0], [90.0, 130.0, 0.0]]

func _session() -> DeliverySession:
	return DeliverySession.new(Wallet.new(), DIST, 1)

func test_payment_on_time_beats_late_and_late_is_never_zero() -> void:
	var on_time := DeliverySession.payment(100, 60.0, 30.0)
	var just := DeliverySession.payment(100, 60.0, 60.0)
	var late := DeliverySession.payment(100, 60.0, 90.0)
	var very_late := DeliverySession.payment(100, 60.0, 10000.0)
	assert_gt(on_time, just)
	assert_gt(just, late)
	assert_gt(late, 0)
	assert_eq(very_late, int(100 * DeliverySession.MIN_LATE_FACTOR))
	assert_gt(on_time, 100, "a tempo dá bónus")

func test_three_colonists_with_distinct_names() -> void:
	var s := _session()
	assert_eq(s.colonists.size(), 3)
	var names := {}
	for c in s.colonists:
		names[c.name] = true
	assert_eq(names.size(), 3)

func test_offers_go_between_different_posts() -> void:
	var s := _session()
	assert_eq(s.offers.size(), DeliverySession.OFFER_COUNT)
	for o in s.offers:
		assert_ne(o.from_post, o.to_post)

func test_longer_routes_pay_more_and_allow_more_time() -> void:
	var s := _session()
	var short := s.make_order(0, 2) # 90 m
	var long := s.make_order(1, 2) # 130 m
	assert_gt(long.base_pay, short.base_pay)
	assert_gt(long.time_limit, short.time_limit)

func test_full_lifecycle_pays_wallet_and_raises_reputation() -> void:
	var s := _session()
	var o: DeliveryOrder = s.offers[0]
	o.crop = "" # sem colheita (encomendas da quinta testam-se em test_farm)
	assert_true(s.accept(o))
	assert_eq(s.target_post(), o.from_post)
	assert_eq(s.offers.size(), DeliverySession.OFFER_COUNT, "a oferta aceite é reposta")
	assert_true(s.pick_up())
	assert_eq(s.target_post(), o.to_post)
	s.tick(5.0)
	var paid := s.deliver()
	assert_gt(paid, o.base_pay)
	assert_eq(s.wallet.credits(), paid)
	assert_eq(s.colonists[o.to_post].reputation, 1)
	assert_null(s.active)

func test_late_delivery_pays_less_and_no_reputation() -> void:
	var s := _session()
	var o: DeliveryOrder = s.offers[0]
	o.crop = "" # sem colheita (encomendas da quinta testam-se em test_farm)
	s.accept(o)
	s.pick_up()
	s.tick(o.time_limit * 1.5)
	var paid := s.deliver()
	assert_lt(paid, o.base_pay)
	assert_gt(paid, 0)
	assert_eq(s.colonists[o.to_post].reputation, 0)

func test_clock_only_runs_while_carrying() -> void:
	var s := _session()
	var o: DeliveryOrder = s.offers[0]
	o.crop = "" # sem colheita (encomendas da quinta testam-se em test_farm)
	s.accept(o)
	s.tick(999.0)
	s.pick_up()
	assert_eq(o.elapsed, 0.0, "o relógio começa ao apanhar a caixa")

func test_invalid_actions_are_refused() -> void:
	var s := _session()
	assert_false(s.pick_up(), "não há encomenda aceite")
	assert_eq(s.deliver(), 0, "nada para entregar")
	var a: DeliveryOrder = s.offers[0]
	var b: DeliveryOrder = s.offers[1]
	assert_true(s.accept(a))
	assert_false(s.accept(b), "só uma encomenda de cada vez")
	assert_eq(s.deliver(), 0, "ainda não apanhou a caixa")

func test_same_seed_same_offers() -> void:
	var a := DeliverySession.new(Wallet.new(), DIST, 9)
	var b := DeliverySession.new(Wallet.new(), DIST, 9)
	for i in a.offers.size():
		assert_eq(a.offers[i].from_post, b.offers[i].from_post)
		assert_eq(a.offers[i].to_post, b.offers[i].to_post)
	assert_eq(a.colonist_name(0), b.colonist_name(0))

func test_fail_active_pays_nothing_and_frees_the_player() -> void:
	var s := _session()
	var o: DeliveryOrder = s.offers[0]
	o.crop = "" # sem colheita (encomendas da quinta testam-se em test_farm)
	s.accept(o)
	s.pick_up()
	watch_signals(s)
	assert_true(s.fail_active())
	assert_eq(o.state, DeliveryOrder.State.FAILED)
	assert_eq(s.wallet.credits(), 0)
	assert_null(s.active)
	assert_signal_emitted(s, "order_failed")
	assert_false(s.fail_active(), "sem encomenda ativa não há nada a falhar")

func test_pushes_lower_the_pay_but_not_below_floor() -> void:
	var s := _session()
	var o: DeliveryOrder = s.offers[0]
	o.crop = "" # sem colheita (encomendas da quinta testam-se em test_farm)
	s.accept(o)
	s.pick_up()
	var clean := DeliverySession.payment(o.base_pay, o.time_limit, 1.0)
	for i in 10:
		s.damage_active()
	assert_almost_eq(o.value_factor, DeliverySession.MIN_VALUE_FACTOR, 0.001)
	s.tick(1.0)
	var paid := s.deliver()
	assert_lt(paid, clean)
	assert_eq(paid, int(round(clean * DeliverySession.MIN_VALUE_FACTOR)))

func test_steal_drop_and_recover() -> void:
	var s := _session()
	var o: DeliveryOrder = s.offers[0]
	o.crop = "" # sem colheita (encomendas da quinta testam-se em test_farm)
	s.accept(o)
	assert_false(s.steal(), "só se rouba o que se está a levar")
	s.pick_up()
	assert_true(s.steal())
	assert_eq(o.state, DeliveryOrder.State.STOLEN)
	assert_eq(s.deliver(), 0, "não se entrega uma caixa roubada")
	assert_true(s.drop(Vector3(1, 2, 3)))
	assert_eq(o.state, DeliveryOrder.State.DROPPED)
	assert_eq(o.drop_position, Vector3(1, 2, 3))
	var t := o.elapsed
	s.tick(2.0)
	assert_gt(o.elapsed, t, "o relógio continua enquanto a caixa está perdida")
	assert_true(s.recover())
	assert_eq(o.state, DeliveryOrder.State.CARRYING)
	assert_lt(o.value_factor, 1.0)

func _deliver_on_time(s: DeliverySession, o: DeliveryOrder) -> int:
	s.accept(o)
	s.pick_up()
	s.tick(1.0)
	return s.deliver()

func test_kinds_change_pay_and_time() -> void:
	var s := _session()
	var n := s.make_order(0, 1, "normal")
	var u := s.make_order(0, 1, "urgent")
	assert_gt(u.base_pay, n.base_pay, "urgente paga mais")
	assert_lt(u.time_limit, n.time_limit, "urgente tem menos tempo")
	assert_gt(s.make_order(0, 1, "special").base_pay, u.base_pay)

func test_fragile_loses_value_with_bumps_others_do_not() -> void:
	var s := _session()
	var f := s.make_order(0, 1, "fragile")
	s.offers.append(f)
	s.accept(f)
	s.pick_up()
	s.bump_active(1.0)
	assert_almost_eq(f.value_factor, 1.0 - DeliverySession.FRAGILE_LOSS_PER_BUMP, 0.001)
	var s2 := _session()
	var nrm := s2.make_order(0, 1, "normal")
	s2.offers.append(nrm)
	s2.accept(nrm)
	s2.pick_up()
	s2.bump_active(1.0)
	assert_eq(nrm.value_factor, 1.0)

func test_perishable_loses_freshness_over_time() -> void:
	var s := _session()
	var p := s.make_order(0, 1, "perishable")
	s.offers.append(p)
	s.accept(p)
	s.pick_up()
	s.tick(p.time_limit * 0.5)
	assert_almost_eq(p.freshness, 1.0 - (1.0 - DeliverySession.PERISH_MIN) * 0.5, 0.01)
	s.tick(p.time_limit * 5.0)
	assert_eq(p.freshness, DeliverySession.PERISH_MIN, "nunca abaixo do mínimo")

func test_important_orders_give_three_keycards_then_lair_opens() -> void:
	var s := _session()
	watch_signals(s)
	var guard := 0
	while s.keycards < DeliverySession.KEYCARDS_PER_PLANET and guard < 40:
		guard += 1
		var imp := s.offers.filter(func(o: DeliveryOrder) -> bool: return o.kind == "important")
		_deliver_on_time(s, imp[0] if not imp.is_empty() else s.offers[0])
	assert_eq(s.keycards, 3)
	assert_true(s.lair_open())
	assert_signal_emit_count(s, "keycard_gained", 3)
	for i in 10:
		_deliver_on_time(s, s.offers[0])
	assert_false(s.has_offer("important"), "só há 3 KeyCards por planeta")

func test_friendship_levels_raise_pay_and_unlock_specials() -> void:
	var s := _session()
	assert_eq(s.friendship_level(1), 1)
	for i in 4:
		var o := s.make_order(0, 1, "normal")
		s.offers.append(o)
		_deliver_on_time(s, o)
	assert_eq(s.friendship_level(1), DeliverySession.SPECIAL_FROM_LEVEL, "4 entregas a tempo = nível 3")
	assert_almost_eq(s.friendship_bonus(1), 1.2, 0.001)
	s.refill_offers()
	assert_true(s.has_offer("special"), "amigo de nível 3 faz encomendas especiais")
