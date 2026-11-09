class_name Research
extends RefCounted
## Pesquisa da nave-mãe (regras puras, F5 #51): compras com dados de pesquisa que ficam de
## planeta para planeta. Compra atómica; os efeitos são lidos por quem os aplica.

signal changed

## linha -> preços (dados) de cada nível.
const LINES := {
	"mech_damage": [{Wallet.DATA: 8}, {Wallet.DATA: 20}, {Wallet.DATA: 40}],
	"mech_armor": [{Wallet.DATA: 8}, {Wallet.DATA: 20}, {Wallet.DATA: 40}],
	"turret_4": [{Wallet.DATA: 30}],
	"building_hp": [{Wallet.DATA: 12}, {Wallet.DATA: 30}],
}
const ORDER := ["mech_damage", "mech_armor", "turret_4", "building_hp"]

var levels := {"mech_damage": 0, "mech_armor": 0, "turret_4": 0, "building_hp": 0}

func level(line: String) -> int:
	return int(levels.get(line, 0))

func max_level(line: String) -> int:
	return (LINES[line] as Array).size()

func next_cost(line: String) -> Dictionary:
	var lv := level(line)
	if not LINES.has(line) or lv >= max_level(line):
		return {}
	return LINES[line][lv]

func buy(line: String, wallet: Wallet) -> bool:
	var cost := next_cost(line)
	if cost.is_empty() or not wallet.spend(cost):
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

func to_dict() -> Dictionary:
	return levels.duplicate()

func from_dict(d: Dictionary) -> void:
	for k in levels:
		levels[k] = clampi(int(d.get(k, 0)), 0, max_level(k))
	changed.emit()
