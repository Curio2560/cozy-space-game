class_name Research
extends RefCounted
## Árvore tecnológica da nave-mãe (regras puras, F5 #51 → F6 #57): 3 ramos com pré-requisitos.
## Compras com dados (e peças nos níveis avançados) que ficam de planeta para planeta.
## Compra atómica; os efeitos são lidos por quem os aplica.

signal changed

const BRANCHES := ["defense", "base", "explore"]

## linha -> {branch, costs (um por nível), req ({linha: nível mínimo})}
const LINES := {
	"mech_damage": {"branch": "defense", "req": {},
		"costs": [{Wallet.DATA: 8}, {Wallet.DATA: 20}, {Wallet.DATA: 40, Wallet.PARTS: 4}]},
	"mech_armor": {"branch": "defense", "req": {},
		"costs": [{Wallet.DATA: 8}, {Wallet.DATA: 20}, {Wallet.DATA: 40, Wallet.PARTS: 4}]},
	"turret_4": {"branch": "defense", "req": {"mech_damage": 1},
		"costs": [{Wallet.DATA: 30}]},
	"building_hp": {"branch": "base", "req": {},
		"costs": [{Wallet.DATA: 12}, {Wallet.DATA: 30}]},
	"crop_yield": {"branch": "base", "req": {},
		"costs": [{Wallet.DATA: 10}, {Wallet.DATA: 25}]},
	"factory": {"branch": "base", "req": {},
		"costs": [{Wallet.DATA: 10}]},
	"helpers": {"branch": "base", "req": {"factory": 1},
		"costs": [{Wallet.DATA: 30, Wallet.PARTS: 5}]},
	"rover_o2": {"branch": "explore", "req": {},
		"costs": [{Wallet.DATA: 10}, {Wallet.DATA: 25}]},
	"heat_shield": {"branch": "explore", "req": {},
		"costs": [{Wallet.DATA: 15}]},
	"cold_suit": {"branch": "explore", "req": {"rover_o2": 1},
		"costs": [{Wallet.DATA: 15}]},
}
const ORDER := ["mech_damage", "mech_armor", "turret_4", "building_hp", "crop_yield", "factory", "helpers", "rover_o2", "heat_shield", "cold_suit"]

var levels := {}

func _init() -> void:
	for k in LINES:
		levels[k] = 0

func level(line: String) -> int:
	return int(levels.get(line, 0))

func max_level(line: String) -> int:
	return (LINES[line].costs as Array).size()

func branch(line: String) -> String:
	return LINES[line].branch

## Pré-requisitos que ainda faltam: {linha: nível}.
func missing(line: String) -> Dictionary:
	var out := {}
	var req: Dictionary = LINES[line].req
	for k in req:
		if level(k) < int(req[k]):
			out[k] = int(req[k])
	return out

func unlocked(line: String) -> bool:
	return missing(line).is_empty()

func next_cost(line: String) -> Dictionary:
	var lv := level(line)
	if not LINES.has(line) or lv >= max_level(line):
		return {}
	return LINES[line].costs[lv]

func buy(line: String, wallet: Wallet) -> bool:
	var cost := next_cost(line)
	if cost.is_empty() or not unlocked(line) or not wallet.spend(cost):
		return false
	levels[line] = level(line) + 1
	changed.emit()
	return true

# Efeitos -------------------------------------------------------------------------------

func mech_damage_factor() -> float:
	return 1.0 + 0.2 * level("mech_damage")

func mech_health_factor() -> float:
	return 1.0 + 0.25 * level("mech_armor")

func max_turret_level() -> int:
	return 3 + level("turret_4")

func building_hp_factor() -> float:
	return 1.0 + 0.3 * level("building_hp")

## Unidades a mais por colheita.
func crop_bonus() -> int:
	return level("crop_yield")

func factory_unlocked() -> bool:
	return level("factory") > 0

func helpers_unlocked() -> bool:
	return level("helpers") > 0

## Multiplicador do gasto de O₂ a pé.
func o2_factor() -> float:
	return 1.0 - 0.2 * level("rover_o2")

## Multiplicador do aquecimento do rover (lava).
func heat_factor() -> float:
	return 0.7 if level("heat_shield") > 0 else 1.0

## Multiplicador do frio a pé (gelo).
func cold_factor() -> float:
	return 0.5 if level("cold_suit") > 0 else 1.0

func to_dict() -> Dictionary:
	return levels.duplicate()

func from_dict(d: Dictionary) -> void:
	for k in LINES:
		levels[k] = clampi(int(d.get(k, 0)), 0, max_level(k))
	changed.emit()
