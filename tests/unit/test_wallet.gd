extends GutTest

func test_starts_empty() -> void:
	var w := Wallet.new()
	for k in Wallet.KINDS:
		assert_eq(w.amount(k), 0)

func test_add_and_spend() -> void:
	var w := Wallet.new()
	w.add(Wallet.CREDITS, 100)
	assert_true(w.spend({Wallet.CREDITS: 40}))
	assert_eq(w.credits(), 60)

func test_spend_is_atomic_and_never_negative() -> void:
	var w := Wallet.new()
	w.add(Wallet.CREDITS, 50)
	w.add(Wallet.ORE, 3)
	assert_false(w.spend({Wallet.CREDITS: 30, Wallet.ORE: 5}), "não chega minério")
	assert_eq(w.credits(), 50, "não pode gastar só uma parte")
	assert_eq(w.amount(Wallet.ORE), 3)
	assert_false(w.spend({Wallet.CREDITS: 51}))
	assert_eq(w.credits(), 50)

func test_negative_add_is_ignored() -> void:
	var w := Wallet.new()
	w.add(Wallet.CREDITS, -10)
	assert_eq(w.credits(), 0)

func test_changed_signal() -> void:
	var w := Wallet.new()
	watch_signals(w)
	w.add(Wallet.CRYSTAL, 2)
	assert_signal_emitted(w, "changed")
