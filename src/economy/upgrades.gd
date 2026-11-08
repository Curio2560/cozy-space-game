class_name Upgrades
extends RefCounted
## Melhorias (regras puras): 4 linhas do rover com 3 níveis e +2 slots do posto (2 vezes).
## Compra atómica; os efeitos são lidos por quem os aplica (rover, entregas, posto).

signal changed

const ROVER_LINES := ["speed", "cargo", "shield", "suspension"]
const MAX_LEVEL := 3
## Preço por nível (1..3) das linhas do rover.
const ROVER_COST := [
	{Wallet.CREDITS: 150},
	{Wallet.CREDITS: 400},
	{Wallet.CREDITS: 900, Wallet.CRYSTAL: 5},
]
const SLOTS_COST := [{Wallet.CREDITS: 500}, {Wallet.CREDITS: 1200, Wallet.CRYSTAL: 5}]

var levels := {"speed": 0, "cargo": 0, "shield": 0, "suspension": 0, "slots": 0}

func level(line: String) -> int:
	return int(levels.get(line, 0))

func max_level(line: String) -> int:
	return SLOTS_COST.size() if line == "slots" else MAX_LEVEL

## Custo do próximo nível, ou {} se já está no máximo.
func next_cost(line: String) -> Dictionary:
	var lv := level(line)
	if lv >= max_level(line):
		return {}
	return (SLOTS_COST if line == "slots" else ROVER_COST)[lv]

func buy(line: String, wallet: Wallet) -> bool:
	var cost := next_cost(line)
	if cost.is_empty() or not wallet.spend(cost):
		return false
	levels[line] = level(line) + 1
	changed.emit()
	return true

# Efeitos -------------------------------------------------------------------------------

## Multiplicador da velocidade máxima do rover.
func speed_factor() -> float:
	return 1.0 + 0.12 * level("speed")

## Multiplicador da perda de valor das caixas em embates (carga mais bem presa).
func cargo_factor() -> float:
	return 1.0 - 0.2 * level("cargo")

## Multiplicador do dano que o rover recebe.
func shield_factor() -> float:
	return 1.0 - 0.2 * level("shield")

## m/s a mais de impacto que o rover aguenta sem dano.
func suspension_bonus() -> float:
	return 1.5 * level("suspension")

func to_dict() -> Dictionary:
	return levels.duplicate()

func from_dict(d: Dictionary) -> void:
	for k in levels:
		levels[k] = clampi(int(d.get(k, 0)), 0, max_level(k))
	changed.emit()
