class_name Crew
extends RefCounted
## Tripulação (regras puras): 4 astronautas com uma vantagem cada que cresce com o nível.
## Só o ativo ganha XP (por entrega). Troca-se no terminal do posto.

signal changed
signal leveled(member: String, level: int)

const MEMBERS := ["FinnTheFrog", "BarbaraTheBee", "FernandoTheFlamingo", "RaeTheRedPanda"]
## XP total para chegar a cada nível (nível 1 = 0).
const LEVEL_XP := [0, 30, 80, 150, 250]
const MAX_LEVEL := 5
const XP_DELIVERY := 10
const XP_ON_TIME := 5

var active := "FinnTheFrog"
var xp := {"FinnTheFrog": 0, "BarbaraTheBee": 0, "FernandoTheFlamingo": 0, "RaeTheRedPanda": 0}

func level(member: String) -> int:
	var lv := 1
	for i in LEVEL_XP.size():
		if int(xp.get(member, 0)) >= LEVEL_XP[i]:
			lv = i + 1
	return mini(lv, MAX_LEVEL)

## XP que falta para o próximo nível (0 no máximo).
func xp_to_next(member: String) -> int:
	var lv := level(member)
	if lv >= MAX_LEVEL:
		return 0
	return LEVEL_XP[lv] - int(xp.get(member, 0))

func select(member: String) -> bool:
	if member not in MEMBERS or member == active:
		return false
	active = member
	changed.emit()
	return true

## Uma entrega feita pelo ativo.
func on_delivery(on_time: bool) -> void:
	var before := level(active)
	xp[active] = int(xp[active]) + XP_DELIVERY + (XP_ON_TIME if on_time else 0)
	if level(active) > before:
		leveled.emit(active, level(active))
	changed.emit()

## Força da vantagem do ativo para `member` (0 se não for o ativo): o nível.
func perk(member: String) -> int:
	return level(member) if active == member else 0

# Efeitos -----------------------------------------------------------------------------

func farm_speed() -> float:
	return 1.0 + 0.1 * perk("BarbaraTheBee")

func jump_factor() -> float:
	return 1.0 + 0.06 * perk("FernandoTheFlamingo")

func walk_factor() -> float:
	return 1.0 + 0.04 * perk("FernandoTheFlamingo")

func acid_factor() -> float:
	return maxf(1.0 - 0.15 * perk("FinnTheFrog"), 0.2)

func o2_factor() -> float:
	return maxf(1.0 - 0.1 * perk("FinnTheFrog"), 0.4)

func drive_factor() -> float:
	return 1.0 + 0.05 * perk("RaeTheRedPanda")

func to_dict() -> Dictionary:
	return {"active": active, "xp": xp.duplicate()}

func from_dict(d: Dictionary) -> void:
	var a := str(d.get("active", "FinnTheFrog"))
	active = a if a in MEMBERS else "FinnTheFrog"
	var x: Dictionary = d.get("xp", {})
	for m in MEMBERS:
		xp[m] = maxi(int(x.get(m, 0)), 0)
	changed.emit()
