class_name TouchControls
extends Control
## Controlos táteis (multitoque): joystick dinâmico na metade esquerda, botões à direita,
## e arrastar no resto do lado direito roda a câmara (via InputHub.add_look).
## Os botões carregam ações do InputMap, por isso o jogo não distingue toque de teclado.

## [ação, chave de tradução, centro relativo ao canto inferior direito (em alturas de ecrã), raio relativo]
const BUTTONS := [
	["jump", "BTN_JUMP", Vector2(-0.16, -0.17), 0.105],
	["action", "BTN_ACTION", Vector2(-0.39, -0.12), 0.08],
	["vehicle", "BTN_VEHICLE", Vector2(-0.12, -0.44), 0.075],
]
const STICK_ZONE := 0.45 # fração da largura do ecrã reservada ao joystick
const COLOR_BASE := Color(1, 0.965, 0.918, 0.28) # estilo cel (CozyTheme)
const COLOR_KNOB := Color(1, 0.965, 0.918, 0.9)
const COLOR_BTN := Color(1, 0.965, 0.918, 0.85)
const COLOR_BTN_DOWN := Color(1.0, 0.78, 0.34, 0.95)

var stick := VirtualStick.new()
var _stick_finger := -1
var _look_finger := -1
var _button_fingers := {} # finger -> ação
var _font: Font
## Troca o texto de um botão (ação -> chave de tradução), p. ex. saltar → DISPARAR no mech.
var label_override := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	stick.radius = _h() * 0.15

func _h() -> float:
	return maxf(size.y, 1.0)

func _idle_stick_center() -> Vector2:
	return Vector2(_h() * 0.24, size.y - _h() * 0.26)

func button_rect_center(i: int) -> Vector2:
	var b: Array = BUTTONS[i]
	var rel: Vector2 = b[2]
	return Vector2(size.x, size.y) + rel * _h()

func button_radius(i: int) -> float:
	return float(BUTTONS[i][3]) * _h()

## Índice do botão sob `pos`, ou -1.
func button_at(pos: Vector2) -> int:
	for i in BUTTONS.size():
		if pos.distance_to(button_rect_center(i)) <= button_radius(i) * 1.15:
			return i
	return -1

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t := make_input_local(event) as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
	elif event is InputEventScreenDrag:
		var d := make_input_local(event) as InputEventScreenDrag
		if d.index == _stick_finger:
			stick.drag(d.position)
			_apply_stick()
		elif d.index == _look_finger:
			InputHub.add_look(d.relative)

func _on_press(finger: int, pos: Vector2) -> void:
	var b := button_at(pos)
	if b >= 0:
		var action: String = BUTTONS[b][0]
		_button_fingers[finger] = action
		Input.action_press(action)
	elif pos.x < size.x * STICK_ZONE and _stick_finger == -1:
		_stick_finger = finger
		stick.press(pos)
		_apply_stick()
	elif _look_finger == -1:
		_look_finger = finger
	queue_redraw()

func _on_release(finger: int) -> void:
	if _button_fingers.has(finger):
		Input.action_release(_button_fingers[finger])
		_button_fingers.erase(finger)
	elif finger == _stick_finger:
		_stick_finger = -1
		stick.release()
		_apply_stick()
	elif finger == _look_finger:
		_look_finger = -1
	queue_redraw()

func _apply_stick() -> void:
	var v := stick.value()
	_set_axis("move_right", v.x)
	_set_axis("move_left", -v.x)
	_set_axis("move_back", v.y)
	_set_axis("move_forward", -v.y)
	queue_redraw()

static func _set_axis(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		stick.radius = _h() * 0.15
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release_all()
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func _exit_tree() -> void:
	_release_all()

func _release_all() -> void:
	for f in _button_fingers.keys():
		Input.action_release(_button_fingers[f])
	_button_fingers.clear()
	_stick_finger = -1
	_look_finger = -1
	stick.release()
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)

func _draw() -> void:
	var c := stick.center if stick.active else _idle_stick_center()
	var k := stick.knob if stick.active else c
	draw_circle(c, stick.radius, COLOR_BASE)
	draw_arc(c, stick.radius, 0, TAU, 48, CozyTheme.INK, 4.0, true)
	draw_circle(k + Vector2(0, 5), stick.radius * 0.42, CozyTheme.INK) # sombra cel
	draw_circle(k, stick.radius * 0.42, COLOR_KNOB)
	draw_arc(k, stick.radius * 0.42, 0, TAU, 32, CozyTheme.INK, 4.0, true)
	var down := _button_fingers.values()
	for i in BUTTONS.size():
		var b: Array = BUTTONS[i]
		var center := button_rect_center(i)
		var r := button_radius(i)
		var pressed: bool = b[0] in down
		if not pressed:
			draw_circle(center + Vector2(0, 6), r, CozyTheme.INK) # sombra cel (afunda ao carregar)
		var at := center + (Vector2(0, 4) if pressed else Vector2.ZERO)
		draw_circle(at, r, COLOR_BTN_DOWN if pressed else COLOR_BTN)
		draw_arc(at, r, 0, TAU, 48, CozyTheme.INK, 4.0, true)
		center = at
		var label := tr(label_override.get(b[0], b[1]))
		var fs := maxi(int(r * 0.42), 8)
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(_font, center + Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CozyTheme.INK)
