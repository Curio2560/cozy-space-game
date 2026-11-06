extends Node
## Ponto único de input do jogo (autoload InputHub).
## - Regista as ações (teclado, comando) se ainda não existirem.
## - `move_vector()`: movimento 0..1 (x direita, y para a frente) vindo de qualquer fonte.
## - Câmara: os controlos táteis e o rato acumulam deslocamento com `add_look()`;
##   a câmara lê-o uma vez por frame com `consume_look()` (inclui o stick direito do comando).

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT, [JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [KEY_D, KEY_RIGHT, [JOY_AXIS_LEFT_X, 1.0]],
	"move_forward": [KEY_W, KEY_UP, [JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [KEY_S, KEY_DOWN, [JOY_AXIS_LEFT_Y, 1.0]],
	"look_left": [KEY_J, [JOY_AXIS_RIGHT_X, -1.0]],
	"look_right": [KEY_L, [JOY_AXIS_RIGHT_X, 1.0]],
	"look_up": [KEY_I, [JOY_AXIS_RIGHT_Y, -1.0]],
	"look_down": [KEY_K, [JOY_AXIS_RIGHT_Y, 1.0]],
	"jump": [KEY_SPACE, JOY_BUTTON_A],
	"action": [KEY_E, JOY_BUTTON_X],
	"vehicle": [KEY_F, JOY_BUTTON_Y],
	"debug_toggle": [KEY_F3],
}
## Velocidade da câmara com o stick/teclas, em "píxeis de arrasto" por segundo.
const LOOK_STICK_SPEED := 900.0

var _look := Vector2.ZERO

func _ready() -> void:
	register_actions()

static func register_actions() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for e in ACTIONS[action]:
			InputMap.action_add_event(action, _event_for(e))

static func _event_for(e: Variant) -> InputEvent:
	if e is Array:
		var m := InputEventJoypadMotion.new()
		m.axis = e[0]
		m.axis_value = e[1]
		return m
	if int(e) < 32: # botões de comando são 0..20; teclas começam em 32 (espaço)
		var b := InputEventJoypadButton.new()
		b.button_index = e
		return b
	var k := InputEventKey.new()
	k.physical_keycode = e
	return k

func move_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	return v.limit_length(1.0)

func add_look(relative: Vector2) -> void:
	_look += relative

## Deslocamento acumulado para a câmara desde a última chamada (em píxeis de arrasto).
func consume_look(delta: float) -> Vector2:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var out := _look + stick * LOOK_STICK_SPEED * delta
	_look = Vector2.ZERO
	return out

func _unhandled_input(event: InputEvent) -> void:
	# No PC: arrastar com o botão direito do rato roda a câmara.
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		add_look((event as InputEventMouseMotion).relative)
