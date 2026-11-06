class_name VirtualStick
extends RefCounted
## Matemática do joystick virtual (sem nós): dado o centro e a posição do dedo devolve
## um vetor com comprimento 0..1, com zona morta e limitado ao raio.

var radius: float
var deadzone: float
var center := Vector2.ZERO
var knob := Vector2.ZERO
var active := false

func _init(p_radius := 110.0, p_deadzone := 0.12) -> void:
	radius = p_radius
	deadzone = p_deadzone

func press(pos: Vector2) -> void:
	center = pos
	knob = pos
	active = true

func drag(pos: Vector2) -> void:
	if not active:
		return
	var d := pos - center
	knob = center + d.limit_length(radius)

func release() -> void:
	active = false
	knob = center

## Vetor em ecrã (x para a direita, y para baixo), comprimento 0..1.
func value() -> Vector2:
	if not active:
		return Vector2.ZERO
	var d := (knob - center) / radius
	var l := d.length()
	if l < deadzone:
		return Vector2.ZERO
	# Reescala para começar em 0 logo a seguir à zona morta.
	return d.normalized() * clampf((l - deadzone) / (1.0 - deadzone), 0.0, 1.0)
