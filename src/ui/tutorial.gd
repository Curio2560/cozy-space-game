class_name Tutorial
extends Control
## Tutorial: passos iniciais que avançam sozinhos quando o jogador os faz, e dicas de
## desbloqueio que aparecem uma vez quando cada sistema fica relevante. Um cartão no topo do
## ecrã com o texto e "Saltar". Estado no save.

signal changed

## Passos iniciais: [chave de texto, condição (Callable sem argumentos → bool)].
var steps: Array = []
## Dicas: [chave de texto, condição]. Mostram-se uma vez, por ordem, quando não há passo ativo.
var tips: Array = []
var step := 0
var seen: Array[String] = []
var _tip := ""
var _tip_t := 0.0
const TIP_TIME := 9.0

var _card: PanelContainer
var _text: Label
var _count: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.position.y = 190
	_card.custom_minimum_size = Vector2(640, 0)
	add_child(_card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_card.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 18)
	_count.add_theme_color_override("font_color", CozyTheme.PEACH)
	v.add_child(_count)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 24)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(520, 0)
	v.add_child(_text)
	var skip := Button.new()
	skip.text = "TUT_SKIP"
	skip.custom_minimum_size = Vector2(120, 56)
	skip.add_theme_font_size_override("font_size", 20)
	skip.pressed.connect(skip_current)
	h.add_child(skip)
	_refresh()

func in_intro() -> bool:
	return step < steps.size()

## Salta o passo atual (ou a dica que está à vista).
func skip_current() -> void:
	if _tip != "":
		_tip = ""
	elif in_intro():
		step = steps.size() # saltar o tutorial inicial todo
	changed.emit()
	_refresh()

func restart() -> void:
	step = 0
	seen.clear()
	_tip = ""
	changed.emit()
	_refresh()

func _process(delta: float) -> void:
	if in_intro():
		var cond: Callable = steps[step][1]
		if cond.call():
			step += 1
			changed.emit()
			_refresh()
		return
	if _tip != "":
		_tip_t -= delta
		if _tip_t <= 0.0:
			_tip = ""
			_refresh()
		return
	for t in tips:
		if t[0] in seen:
			continue
		if (t[1] as Callable).call():
			seen.append(t[0])
			_tip = t[0]
			_tip_t = TIP_TIME
			changed.emit()
			_refresh()
			break

func current_text_key() -> String:
	if in_intro():
		return steps[step][0]
	return _tip

func _refresh() -> void:
	if _card == null:
		return
	var key := current_text_key()
	_card.visible = key != ""
	_text.text = tr(key) if key != "" else ""
	_count.text = (tr("TUT_STEP") % [step + 1, steps.size()]) if in_intro() else tr("TUT_TIP")

func to_dict() -> Dictionary:
	return {"step": step, "seen": seen.duplicate()}

func from_dict(d: Dictionary) -> void:
	step = clampi(int(d.get("step", 0)), 0, steps.size())
	seen.clear()
	for k in d.get("seen", []):
		seen.append(str(k))
	_refresh()
