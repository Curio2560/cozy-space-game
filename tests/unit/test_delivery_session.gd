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
	s.accept(o)
	s.pick_up()
	watch_signals(s)
	assert_true(s.fail_active())
	assert_eq(o.state, DeliveryOrder.State.FAILED)
	assert_eq(s.wallet.credits(), 0)
	assert_null(s.active)
	assert_signal_emitted(s, "order_failed")
	assert_false(s.fail_active(), "sem encomenda ativa não há nada a falhar")
