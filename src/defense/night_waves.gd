class_name NightWaves
extends RefCounted
## Vagas da noite (regras puras, F4 #38): 3 vagas por noite, cada noite um pouco mais forte.
## A primeira noite é mais fácil (tutorial). A cena pede as criaturas pelo sinal `spawn` e
## avisa as mortes com `killed()`.

signal wave_started(wave: int, count: int) # wave 1..WAVES
signal wave_cleared(wave: int)
signal spawn(count: int, health: float)
signal changed

const WAVES := 3
## Segundos (desde o início da noite) em que cada vaga chega, no máximo.
const WAVE_AT := [6.0, 62.0, 118.0]
## Se a vaga anterior acabar antes, a seguinte chega depois desta pausa.
const BREAK := 10.0
const MAX_PER_WAVE := 12
const BASE_HEALTH := 30.0

var night := 0 # 0 = sem noite em curso
var wave := 0 # última vaga lançada (0 = nenhuma ainda)
var alive := 0 # criaturas da vaga atual ainda vivas
var cleared := 0 # vagas vencidas nesta noite
var clock := 0.0
var _next_at := 0.0

## Criaturas na vaga `w` (1..3) da noite `n` (1..).
static func wave_size(n: int, w: int) -> int:
	var base := 2 if n <= 1 else 3
	return mini(base + (w - 1) + (n - 1), MAX_PER_WAVE)

## Recompensa por vencer a vaga `w` da noite `n` (#42): créditos e dados de pesquisa.
static func wave_reward(n: int, w: int) -> Dictionary:
	return {Wallet.CREDITS: 30 + 15 * n + 10 * (w - 1), Wallet.DATA: 1 + (n - 1) / 2}

## Bónus da noite perfeita (todas as vagas vencidas, nenhum edifício danificado).
static func perfect_bonus(n: int) -> Dictionary:
	return {Wallet.CREDITS: 60 + 20 * n, Wallet.DATA: 2}

## Vida de cada criatura na noite `n`.
static func creature_health(n: int) -> float:
	return BASE_HEALTH * (1.0 + 0.15 * (n - 1))

func active() -> bool:
	return night > 0

func start_night(n: int) -> void:
	night = maxi(n, 1)
	wave = 0
	alive = 0
	cleared = 0
	clock = 0.0
	_next_at = WAVE_AT[0]
	changed.emit()

## Acaba a noite (amanheceu): as criaturas que restam fogem.
func end_night() -> void:
	night = 0
	alive = 0
	changed.emit()

func tick(delta: float) -> void:
	if not active():
		return
	clock += delta
	if wave < WAVES and clock >= _next_at:
		launch_next()

## Lança já a vaga seguinte (também pelo DBG).
func launch_next() -> void:
	if not active() or wave >= WAVES:
		return
	wave += 1
	var n := wave_size(night, wave)
	alive += n
	wave_started.emit(wave, n)
	spawn.emit(n, creature_health(night))
	_next_at = WAVE_AT[wave] if wave < WAVES else INF
	changed.emit()

## Uma criatura da noite morreu.
func killed() -> void:
	if not active() or alive <= 0:
		return
	alive -= 1
	if alive == 0:
		# Vagas sobrepostas: todas as lançadas até agora ficam vencidas.
		for w in range(cleared + 1, wave + 1):
			wave_cleared.emit(w)
		cleared = wave
		if wave < WAVES:
			_next_at = minf(_next_at, clock + BREAK)
	changed.emit()

func all_cleared() -> bool:
	return cleared >= WAVES
