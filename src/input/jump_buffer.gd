class_name JumpBuffer
extends RefCounted
## Deteta o carregar do botão de salto no passo de física e guarda-o durante `window`
## segundos, para um toque não se perder entre frames nem por chegar um pouco antes do chão.

var window := 0.12
var _held := false
var _timer := 0.0

## Chamar uma vez por passo de física com o estado atual do botão.
func update(pressed: bool, delta: float) -> void:
	if pressed and not _held:
		_timer = window
	elif _timer > 0.0:
		_timer -= delta
	_held = pressed

## Devolve true (uma só vez) se houver um salto pedido dentro da janela.
func consume() -> bool:
	if _timer > 0.0:
		_timer = 0.0
		return true
	return false
