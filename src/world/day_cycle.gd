class_name DayCycle
extends RefCounted
## Relógio do planeta (regras puras, F4 #37): 7 min de dia + 3 min de noite.
## Aviso 30 s antes do anoitecer. `time` conta os segundos desde o início do dia atual.

signal dusk_warning
signal night_started(day: int)
signal morning(day: int) # `day` = o dia que começa
signal changed

const DAY_LEN := 420.0
const NIGHT_LEN := 180.0
const CYCLE_LEN := DAY_LEN + NIGHT_LEN
const WARN_BEFORE := 30.0
## Segundos de transição (luz) ao anoitecer e ao amanhecer.
const FADE := 20.0
## Bónus das entregas feitas à noite.
const NIGHT_PAY := 1.25

var day := 1
var time := 0.0
## Multiplicador do tempo (DBG: acelerar).
var speed := 1.0
## Pausado (p. ex. durante o ecrã da manhã).
var paused := false
var _warned := false

func is_night() -> bool:
	return time >= DAY_LEN

func time_to_night() -> float:
	return maxf(DAY_LEN - time, 0.0)

func time_to_morning() -> float:
	return CYCLE_LEN - time if is_night() else 0.0

## 0..1 do dia (ou da noite) que já passou.
func phase_progress() -> float:
	return (time - DAY_LEN) / NIGHT_LEN if is_night() else time / DAY_LEN

## Luz do dia: 1 de dia, 0 de noite, com transições suaves de FADE s em cada ponta da noite.
func daylight() -> float:
	if time < DAY_LEN - FADE:
		return 1.0 if time >= FADE * 0.5 else 0.5 + 0.5 * (time / (FADE * 0.5))
	if time < DAY_LEN:
		return 1.0 - smoothstep(DAY_LEN - FADE, DAY_LEN, time)
	if time < CYCLE_LEN - FADE * 0.5:
		return 0.0
	return 0.5 * smoothstep(CYCLE_LEN - FADE * 0.5, CYCLE_LEN, time)

## Multiplicador do pagamento de uma entrega feita agora.
func pay_factor() -> float:
	return NIGHT_PAY if is_night() else 1.0

func tick(delta: float) -> void:
	if paused or delta <= 0.0:
		return
	var left := delta * speed
	# Passo a passo para nunca saltar um evento (aviso, noite, manhã) com o tempo acelerado.
	while left > 0.0 and not paused:
		var event := ""
		var to_event: float
		if not _warned and time < DAY_LEN - WARN_BEFORE:
			event = "warn"
			to_event = DAY_LEN - WARN_BEFORE - time
		elif time < DAY_LEN:
			event = "night"
			to_event = DAY_LEN - time
		else:
			event = "morning"
			to_event = CYCLE_LEN - time
		if left < to_event:
			time += left
			break
		time += to_event
		left -= to_event
		match event:
			"warn":
				_warned = true
				dusk_warning.emit()
			"night":
				_warned = true
				time = DAY_LEN + 0.0001 # já é noite
				night_started.emit(day)
			"morning":
				time = 0.0
				day += 1
				_warned = false
				morning.emit(day)
	changed.emit()

## DBG: salta para o início da noite (dispara os eventos pelo caminho).
func skip_to_night() -> void:
	if is_night():
		return
	var s := speed
	speed = 1.0
	tick(DAY_LEN - time)
	speed = s

## DBG / fim da noite: salta para o início do dia seguinte.
func skip_to_morning() -> void:
	var s := speed
	speed = 1.0
	if not is_night():
		tick(DAY_LEN - time)
	tick(CYCLE_LEN - time)
	speed = s

func to_dict() -> Dictionary:
	return {"day": day, "time": time}

func from_dict(d: Dictionary) -> void:
	day = maxi(int(d.get("day", 1)), 1)
	time = clampf(float(d.get("time", 0.0)), 0.0, CYCLE_LEN - 0.01)
	_warned = time >= DAY_LEN - WARN_BEFORE
	changed.emit()
