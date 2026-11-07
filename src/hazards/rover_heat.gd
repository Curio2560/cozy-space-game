class_name RoverHeat
extends RefCounted
## Calor do rover no bioma de lava (regras puras, sem cena).
## - Aquece com a velocidade, mais perto das fissuras e muito dentro delas.
## - Arrefece parado e à sombra (árvores, rochas, edifícios ao lado).
## - A 100 sobreaquece: fica lento até arrefecer abaixo de COOL_OK.

signal changed
signal overheated

const MAX := 100.0
const COOL_OK := 55.0 # abaixo disto deixa de estar sobreaquecido
const SPEED_HEAT := 3.0 # /s à velocidade máxima
const NEAR_FISSURE_M := 9.0
const NEAR_HEAT := 10.0 # /s mesmo à beira da fissura
const IN_FISSURE_HEAT := 35.0
const PARKED_COOL := 9.0 # /s parado
const SHADE_COOL := 7.0 # /s a mais à sombra
const DRIVE_COOL := 1.5 # /s a andar longe de tudo (o ar arrefece um pouco)
const SLOW_SPEED := 2.0 # m/s: abaixo disto conta como parado
const OVERHEAT_SPEED := 0.4 # fração da velocidade máxima sobreaquecido

var heat := 0.0
var hot := false # sobreaquecido

## `speed01` = velocidade / velocidade máxima (0..1); `fissure_clearance` em m (INF = longe).
func tick(delta: float, speed_m_s: float, speed01: float, fissure_clearance: float, in_shade: bool) -> void:
	var before := heat
	var rate := SPEED_HEAT * clampf(speed01, 0.0, 1.0)
	if fissure_clearance < 0.0:
		rate += IN_FISSURE_HEAT
	else:
		rate += NEAR_HEAT * (1.0 - clampf(fissure_clearance / NEAR_FISSURE_M, 0.0, 1.0))
	if absf(speed_m_s) < SLOW_SPEED:
		rate -= PARKED_COOL
	else:
		rate -= DRIVE_COOL
	if in_shade:
		rate -= SHADE_COOL
	heat = clampf(heat + rate * delta, 0.0, MAX)
	if not hot and heat >= MAX:
		hot = true
		overheated.emit()
	elif hot and heat < COOL_OK:
		hot = false
	if heat != before:
		changed.emit()

## Multiplicador da velocidade máxima do rover.
func speed_factor() -> float:
	return OVERHEAT_SPEED if hot else 1.0

func reset() -> void:
	heat = 0.0
	hot = false
	changed.emit()

const SHADE_M := 2.5 # distância à borda de uma árvore/rocha/edifício para estar à sombra

## À sombra em `dir` (perto de um obstáculo: árvore, pedregulho, edifício)?
static func in_shade(d: PlanetData, dir: Vector3) -> bool:
	var p := dir.normalized() * d.radius
	for o in d.obstacles_near(dir):
		if p.distance_to(o[0]) < float(o[1]) + SHADE_M:
			return true
	return false
