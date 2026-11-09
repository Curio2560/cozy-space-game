class_name DepartDialog
extends PanelContainer
## Partir na nave (F5 #48): mostra o que fica no planeta (minério, cristal, colheitas) e quanto
## vale vender, e deixa escolher: vender tudo e partir, partir sem vender, ou ficar.

signal chosen(choice: String) # "sell", "go" ou "stay"

const LEFT_BEHIND := [Wallet.ORE, Wallet.CRYSTAL, Wallet.CROP_FAST, Wallet.CROP_MID, Wallet.CROP_SLOW]

var wallet: Wallet
var _text: Label
var _sell: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(820, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var t := Label.new()
	t.text = "DEPART_TITLE"
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", CozyTheme.PEACH)
	t.add_theme_color_override("font_outline_color", CozyTheme.INK)
	t.add_theme_constant_override("outline_size", 8)
	v.add_child(t)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 24)
	v.add_child(_text)
	_sell = _button("DEPART_SELL", "sell")
	v.add_child(_sell)
	v.add_child(_button("DEPART_GO", "go"))
	v.add_child(_button("DEPART_STAY", "stay"))

func _button(key: String, choice: String) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func() -> void: chosen.emit(choice))
	return b

## Valor (¢) de tudo o que fica no planeta.
static func left_value(w: Wallet) -> int:
	var v := 0
	for k in LEFT_BEHIND:
		v += w.amount(k) * Market.price(k)
	return v

func open() -> void:
	var parts := []
	for k in LEFT_BEHIND:
		if wallet.amount(k) > 0:
			parts.append("%d %s" % [wallet.amount(k), tr("RES_" + k.to_upper())])
	if parts.is_empty():
		_text.text = tr("DEPART_NOTHING")
		_sell.visible = false
	else:
		_text.text = tr("DEPART_LEFT") % [", ".join(parts), left_value(wallet)]
		_sell.visible = true
		_sell.text = tr("DEPART_SELL") % left_value(wallet)
	visible = true
