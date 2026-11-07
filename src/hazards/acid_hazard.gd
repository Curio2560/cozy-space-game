class_name AcidHazard
extends RefCounted
## Regras dos rios de ácido e das fissuras de lava (puras, sem cena): O₂ gasto pelo ar e mais junto aos rios, dano no
## ácido a pé e ao rover. O rover protege do O₂ (planet_run não gasta O₂ a conduzir).

const NEAR_RIVER_M := 7.0 # a esta distância da margem começa a gastar mais O₂
const NEAR_RIVER_DRAIN := 3.0 # O₂/s a mais mesmo à beira do rio
const FOOT_ACID_DPS := 30.0 # vida/s a pé dentro do ácido
const ROVER_ACID_DPS := 20.0 # vida/s do rover dentro do ácido
const BUBBLE_O2 := 40.0
const BUBBLE_RADIUS_M := 1.6
const BUBBLE_RESPAWN_S := 25.0

## O₂ por segundo gasto a pé em `dir` (`base` = gasto do bioma; `near_k` = quanto os rios
## somam: 1 no ácido, 0 na lava, onde as fissuras queimam mas não gastam O₂).
static func o2_drain(d: PlanetData, dir: Vector3, base: float, near_k := 1.0) -> float:
	if d.rivers.is_empty() or near_k <= 0.0:
		return base
	var c := d.river_clearance(dir)
	var near := 1.0 - clampf(c / NEAR_RIVER_M, 0.0, 1.0)
	return base + NEAR_RIVER_DRAIN * near * near_k

static func foot_damage_rate(d: PlanetData, dir: Vector3) -> float:
	return FOOT_ACID_DPS if d.in_acid(dir) else 0.0

static func rover_damage_rate(d: PlanetData, dir: Vector3) -> float:
	return ROVER_ACID_DPS if d.in_acid(dir) else 0.0
