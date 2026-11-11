class_name MechGun
extends RefCounted
## Arma do mech (regras puras): munições infinitas, sem aquecimento. Enquanto o gatilho estiver
## carregado e houver alvo, sai um projétil a cada INTERVAL segundos.

const INTERVAL := 0.12 # s entre tiros
const DAMAGE := 5.0
const RANGE := 24.0

var _cd := 0.0

## Avança `delta` s com o gatilho `trigger`. Devolve quantos tiros saíram neste passo.
## `has_target`: sem alvo ao alcance não se dispara.
func tick(delta: float, trigger: bool, has_target := true) -> int:
	_cd = maxf(_cd - delta, 0.0)
	if not trigger or not has_target or _cd > 0.0:
		return 0
	_cd = INTERVAL
	return 1

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
