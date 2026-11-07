class_name AcidHazard
extends RefCounted
## Regras do bioma ácido (puras, sem cena): O₂ gasto pelo ar e mais junto aos rios, dano no
## ácido a pé e ao rover. O rover protege do O₂ (planet_run não gasta O₂ a conduzir).

const NEAR_RIVER_M := 7.0 # a esta distância da margem começa a gastar mais O₂
const NEAR_RIVER_DRAIN := 3.0 # O₂/s a mais mesmo à beira do rio
const FOOT_ACID_DPS := 30.0 # vida/s a pé dentro do ácido
const ROVER_ACID_DPS := 12.0 # vida/s do rover dentro do ácido
const BUBBLE_O2 := 40.0
const BUBBLE_RADIUS_M := 1.6
const BUBBLE_RESPAWN_S := 25.0

## O₂ por segundo gasto a pé em `dir` (`base` = gasto do bioma).
static func o2_drain(d: PlanetData, dir: Vector3, base: float) -> float:
	if base <= 0.0 and d.rivers.is_empty():
		return 0.0
	var c := d.river_clearance(dir)
	var near := 1.0 - clampf(c / NEAR_RIVER_M, 0.0, 1.0)
	return base + NEAR_RIVER_DRAIN * near

static func foot_damage_rate(d: PlanetData, dir: Vector3) -> float:
	return FOOT_ACID_DPS if d.in_acid(dir) else 0.0

static func rover_damage_rate(d: PlanetData, dir: Vector3) -> float:
	return ROVER_ACID_DPS if d.in_acid(dir) else 0.0
