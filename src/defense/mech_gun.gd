class_name MechGun
extends RefCounted
## Arma do mech (regras puras, F4 #39): tiro rápido com aquecimento.
## Disparar aquece; parado arrefece. Ao chegar ao máximo bloqueia até arrefecer até RESUME.

signal overheated
signal cooled

const INTERVAL := 0.12 # s entre tiros
const HEAT_PER_SHOT := 4.5
const COOL_RATE := 32.0 # por segundo, sem disparar
const COOL_DELAY := 0.25 # s depois do último tiro até começar a arrefecer
const MAX_HEAT := 100.0
const RESUME := 35.0
const DAMAGE := 6.0
const RANGE := 24.0

var heat := 0.0
var locked := false
var _cd := 0.0
var _since_shot := 99.0

## Avança `delta` s com o gatilho `trigger`. Devolve quantos tiros saíram neste passo.
## `has_target`: sem alvo ao alcance não se dispara (nem aquece).
func tick(delta: float, trigger: bool, has_target := true) -> int:
	_cd = maxf(_cd - delta, 0.0)
	_since_shot += delta
	var shots := 0
	if trigger and has_target and not locked:
		var budget := delta
		while _cd <= 0.0 and not locked:
			shots += 1
			heat = minf(heat + HEAT_PER_SHOT, MAX_HEAT)
			_since_shot = 0.0
			_cd += INTERVAL
			if heat >= MAX_HEAT:
				locked = true
				overheated.emit()
			budget -= INTERVAL
			if budget <= 0.0:
				break
	if shots == 0 and _since_shot >= COOL_DELAY:
		heat = maxf(heat - COOL_RATE * delta, 0.0)
		if locked and heat <= RESUME:
			locked = false
			cooled.emit()
	return shots

## O alvo mais perto de `from` dentro do alcance: índice em `positions`, ou -1.
static func nearest(from: Vector3, positions: Array, max_range := RANGE) -> int:
	var best := -1
	var best_d := max_range
	for i in positions.size():
		var d := from.distance_to(positions[i])
		if d <= best_d:
			best_d = d
			best = i
	return best
