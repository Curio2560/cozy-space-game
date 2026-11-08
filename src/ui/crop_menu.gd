class_name CropMenu
extends PanelContainer
## Menu de um talhão vazio: escolher a cultura (tempo, semente, preço de venda) e plantar.

signal closed

var controller: FarmController
var plot := -1
var _list: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(820, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var t := Label.new()
	t.text = "CROP_MENU_TITLE"
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", CozyTheme.PEACH)
	t.add_theme_color_override("font_outline_color", CozyTheme.INK)
	t.add_theme_constant_override("outline_size", 8)
	v.add_child(t)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	v.add_child(_list)
	var close := Button.new()
	close.text = "UI_CLOSE"
	close.custom_minimum_size = Vector2(0, 60)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func() -> void: closed.emit())
	v.add_child(close)

func open(i: int) -> void:
	plot = i
	for c in _list.get_children():
		c.queue_free()
	for crop in Farm.ORDER:
		var c: Dictionary = Farm.CROPS[crop]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 24)
		l.text = tr("CROP_INFO") % [tr("CROP_" + crop.to_upper()), DeliveryHud.format_time(float(c.time) / controller.farm.growth_speed), int(c.seed), Farm.YIELD, Market.price(c.resource)]
		row.add_child(l)
		var b := Button.new()
		b.text = "CROP_PLANT"
		b.custom_minimum_size = Vector2(170, 64)
		b.add_theme_font_size_override("font_size", 24)
		b.disabled = not controller.run.wallet.can_afford({Wallet.CREDITS: int(c.seed)})
		b.pressed.connect(func() -> void:
			if controller.plant(plot, crop):
				closed.emit())
		row.add_child(b)
		_list.add_child(row)
	visible = true
