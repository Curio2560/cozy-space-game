class_name PlayerVitals
extends RefCounted
## Vida e O₂ do astronauta (regras puras, sem cena).
## - O O₂ desce à taxa `o2_drain` (por segundo) que os perigos definem a cada frame.
## - Sem O₂ a vida desce depressa. A vida a 0 = desmaio (sinal `fainted`, uma vez).
## - A vida recupera devagar depois de uns segundos sem dano; o O₂ recupera onde não se gasta.

signal changed
signal fainted

const MAX_HEALTH := 100.0
const MAX_O2 := 100.0
const NO_O2_DAMAGE := 18.0 # vida por segundo sem O₂
const REGEN_DELAY := 4.0
const REGEN_RATE := 6.0
const O2_RECOVER := 25.0 # O₂ por segundo quando não se gasta

var health := MAX_HEALTH
var o2 := MAX_O2
var o2_drain := 0.0
var down := false
var _since_hit := 99.0

func tick(delta: float) -> void:
	if down:
		return
	var before := [health, o2]
	if o2_drain > 0.0:
		o2 = maxf(o2 - o2_drain * delta, 0.0)
	else:
		o2 = minf(o2 + O2_RECOVER * delta, MAX_O2)
	if o2 <= 0.0:
		_hurt(NO_O2_DAMAGE * delta)
	else:
		_since_hit += delta
		if _since_hit > REGEN_DELAY:
			health = minf(health + REGEN_RATE * delta, MAX_HEALTH)
	if before[0] != health or before[1] != o2:
		changed.emit()

func damage(amount: float) -> void:
	if down or amount <= 0.0:
		return
	_hurt(amount)
	changed.emit()

func add_o2(amount: float) -> void:
	if down:
		return
	o2 = minf(o2 + amount, MAX_O2)
	changed.emit()

func reset() -> void:
	health = MAX_HEALTH
	o2 = MAX_O2
	o2_drain = 0.0
	down = false
	_since_hit = 99.0
	changed.emit()

func _hurt(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	_since_hit = 0.0
	if health <= 0.0 and not down:
		down = true
		fainted.emit()
