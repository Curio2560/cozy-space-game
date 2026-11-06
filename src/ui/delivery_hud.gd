class_name DeliveryHud
extends Control
## HUD das entregas: créditos, encomenda ativa (destino, distância, relógio), seta e
## mensagens curtas (+créditos).

var credits_label: Label
var keycards_label: Label
var order_label: Label
var arrow: NavArrow
var _toast: Label
var _toast_time := 0.0

static func format_time(seconds: float) -> String:
	var s := int(ceil(absf(seconds)))
	return "%s%d:%02d" % ["-" if seconds < 0.0 else "", s / 60, s % 60]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_label = _label(30, Color("ffc857"))
	credits_label.position = Vector2(104, 26)
	add_child(credits_label)
	keycards_label = _label(22, Color("b79cff"))
	keycards_label.position = Vector2(200, 30)
	add_child(keycards_label)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position.y = 70
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	arrow = NavArrow.new()
	arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(arrow)
	order_label = _label(26, Color("fff6ea"))
	order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(order_label)
	_toast = _label(40, Color("6fd6b4"))
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position.y -= 120
	add_child(_toast)

func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.5
	_toast.modulate.a = 1.0

func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)

func _label(size_px: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.14, 0.1, 0.22))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
