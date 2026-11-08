class_name Market
extends RefCounted
## Venda de recursos no terminal do posto (regras puras). Minério, cristal e colheitas ficam
## no planeta: vendem-se antes de partir. Os dados de pesquisa não se vendem.

const PRICES := {Wallet.ORE: 4, Wallet.CRYSTAL: 15, Wallet.CROP_FAST: 6, Wallet.CROP_MID: 12, Wallet.CROP_SLOW: 20}

static func can_sell(kind: String) -> bool:
	return PRICES.has(kind)

static func price(kind: String) -> int:
	return int(PRICES.get(kind, 0))

## Vende `count` (ou tudo, se count < 0) de `kind`. Atómico. Devolve os créditos ganhos.
static func sell(wallet: Wallet, kind: String, count := -1) -> int:
	if not can_sell(kind):
		return 0
	var have := wallet.amount(kind)
	var n := have if count < 0 else mini(count, have)
	if n <= 0 or not wallet.spend({kind: n}):
		return 0
	var got := n * price(kind)
	wallet.add(Wallet.CREDITS, got)
	return got
