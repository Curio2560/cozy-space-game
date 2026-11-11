class_name BossRules
extends RefCounted
## Regras do boss (puras, F5 #47): vida por planeta, fases pela vida, golpes e tempos.

## Monstro de cada bioma (um grande do pack); o resto escolhe pelo índice do planeta.
const MODELS := {"prado": "big/MushroomKing", "acido": "big/BlueDemon", "lava": "big/Demon", "gelo": "big/Yeti"}
const FALLBACK := ["big/Yeti", "big/Dino", "big/Orc_Skull", "big/Cactoro"]
const SCALE := 3.0
const BASE_HEALTH := 900.0

## Golpe no chão: raio do círculo, tempo de aviso (por fase 1..3), dano ao mech.
const SLAM_RADIUS := 3.6
const SLAM_WINDUP := [1.3, 1.1, 0.8]
const SLAM_DAMAGE := 26.0
const SLAM_COOLDOWN := [2.6, 2.4, 1.6]
## Ataque em área (fase 3): anel à volta do boss.
const AREA_RADIUS := 8.0
const AREA_WINDUP := 1.5
const AREA_DAMAGE := 22.0
const AREA_EVERY := 4 # um em cada N golpes na fase 3
## Fase 2+: chama criaturas.
const SUMMON_COUNT := 3
const SUMMON_EVERY := 14.0
const SPEED := [2.2, 2.4, 3.4]
const KEEP_DISTANCE := 3.5

## Recompensa por vencer o boss do planeta `planet_index`.
static func reward(planet_index: int) -> Dictionary:
	return {Wallet.CREDITS: 600 + 300 * planet_index, Wallet.DATA: 12 + 6 * planet_index}

## Vida do boss no planeta `planet_index` (0 = o primeiro).
static func health(planet_index: int) -> float:
	return BASE_HEALTH * (1.0 + 0.35 * planet_index)

## Fase (1..3) pela fração de vida.
static func phase(frac: float) -> int:
	if frac > 0.66:
		return 1
	if frac > 0.33:
		return 2
	return 3

static func model_for(biome: String, planet_index: int) -> String:
	if MODELS.has(biome):
		return MODELS[biome]
	return FALLBACK[planet_index % FALLBACK.size()]

## Um golpe apanha `p` se estiver dentro do círculo (distância no chão, m).
static func hits(dist_m: float, radius: float) -> bool:
	return dist_m <= radius
