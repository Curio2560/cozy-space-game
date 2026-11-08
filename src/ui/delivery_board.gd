class_name DeliveryBoard
extends PanelContainer
## Quadro de encomendas (no posto avançado): lista as ofertas da sessão com botão Aceitar.

signal accepted(order: DeliveryOrder)
signal closed

var session: DeliverySession
const KIND_COLORS := {"urgent": Color("d8452f"), "fragile": Color("3b7fc4"), "perishable": Color("3a9a5b"), "important": Color("8a4fd6"), "special": Color("c77a12")}
var _list: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(720, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var title := Label.new()
	title.text = "BOARD_TITLE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", CozyTheme.PEACH)
	title.add_theme_color_override("font_outline_color", CozyTheme.INK)
	title.add_theme_constant_override("outline_size", 8)
	v.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	v.add_child(_list)
	var close := Button.new()
	close.text = "UI_CLOSE"
	close.custom_minimum_size = Vector2(0, 64)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func() -> void: closed.emit())
	v.add_child(close)

func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if session.active != null:
		var busy := Label.new()
		busy.text = "BOARD_BUSY"
		busy.add_theme_font_size_override("font_size", 24)
		busy.add_theme_color_override("font_color", Color(CozyTheme.INK, 0.65))
		_list.add_child(busy)
	for o in session.offers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = "[%s]  %s → %s   ·   %d ¢   ·   %s" % [tr("KIND_" + o.kind.to_upper()), session.colonist_name(o.from_post), session.colonist_name(o.to_post), o.base_pay, DeliveryHud.format_time(o.time_limit)]
		if o.crop != "":
			info.text += "\n" + tr("BOARD_NEEDS_CROP") % [tr("RES_" + o.crop.to_upper()), session.wallet.amount(o.crop)]
		info.add_theme_font_size_override("font_size", 26)
		info.add_theme_color_override("font_color", KIND_COLORS.get(o.kind, CozyTheme.INK))
		row.add_child(info)
		var b := Button.new()
		b.text = "BOARD_ACCEPT"
		b.custom_minimum_size = Vector2(170, 64)
		b.add_theme_font_size_override("font_size", 24)
		b.disabled = not session.can_accept(o)
		b.pressed.connect(func() -> void: accepted.emit(o))
		row.add_child(b)
		_list.add_child(row)
