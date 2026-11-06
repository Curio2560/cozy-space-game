class_name Wallet
extends RefCounted
## Carteira do jogador: créditos e os 4 recursos. Nunca fica negativa; gastar é atómico.

signal changed

const CREDITS := "credits"
const ORE := "ore"
const CRYSTAL := "crystal"
const CROPS := "crops"
const DATA := "data"
const KINDS := [CREDITS, ORE, CRYSTAL, CROPS, DATA]

var _amounts := {}

func _init() -> void:
	for k in KINDS:
		_amounts[k] = 0

func amount(kind: String) -> int:
	return _amounts.get(kind, 0)

func credits() -> int:
	return amount(CREDITS)

func add(kind: String, value: int) -> void:
	assert(kind in KINDS, "recurso desconhecido: %s" % kind)
	if value <= 0:
		return
	_amounts[kind] += value
	changed.emit()

## `cost`: {tipo: quantidade}.
func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if amount(k) < int(cost[k]):
			return false
	return true

## Gasta tudo ou nada. Devolve se gastou.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		_amounts[k] -= int(cost[k])
	changed.emit()
	return true

func to_dict() -> Dictionary:
	return _amounts.duplicate()
