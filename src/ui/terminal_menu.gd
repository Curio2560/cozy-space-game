class_name TerminalMenu
extends PanelContainer
## Terminal do posto avançado: um menu com separadores (Construir, Upgrades, Vender,
## Tripulação). Cada sistema regista o seu separador com add_page().

signal closed

var wallet: Wallet
var _tabs: TabContainer
var _sell_rows := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(820, 520)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var title := Label.new()
	title.text = "TERMINAL_TITLE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", CozyTheme.PEACH)
	title.add_theme_color_override("font_outline_color", CozyTheme.INK)
	title.add_theme_constant_override("outline_size", 8)
	v.add_child(title)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 26)
	v.add_child(_tabs)
	add_page("TERMINAL_TAB_SELL", _sell_page())
	var close := Button.new()
	close.text = "UI_CLOSE"
	close.custom_minimum_size = Vector2(0, 64)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func() -> void: closed.emit())
	v.add_child(close)

## Junta um separador (o nome é uma chave de tradução). Devolve o índice.
func add_page(title_key: String, page: Control, first := false) -> int:
	page.name = title_key
	_tabs.add_child(page)
	if first:
		_tabs.move_child(page, 0)
		_tabs.current_tab = 0
	return page.get_index()

func page_count() -> int:
	return _tabs.get_tab_count()

func refresh() -> void:
	for kind in _sell_rows:
		var row: Array = _sell_rows[kind]
		(row[0] as Label).text = "%s: %d   ·   %d ¢ / %s" % [tr("RES_" + kind.to_upper()), wallet.amount(kind), Market.price(kind), tr("UNIT")]
		(row[1] as Button).disabled = wallet.amount(kind) <= 0
		(row[2] as Button).disabled = wallet.amount(kind) <= 0
	for i in _tabs.get_tab_count():
		var c := _tabs.get_tab_control(i)
		if c.has_method("refresh"):
			c.refresh()

func _sell_page() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	for kind in Market.PRICES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 26)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var one := _button("SELL_ONE")
		one.pressed.connect(func() -> void: _sell(kind, 1))
		row.add_child(one)
		var all := _button("SELL_ALL")
		all.pressed.connect(func() -> void: _sell(kind, -1))
		row.add_child(all)
		col.add_child(row)
		_sell_rows[kind] = [l, one, all]
	return col

signal sold(kind: String, credits: int)

func _sell(kind: String, n: int) -> void:
	var got := Market.sell(wallet, kind, n)
	if got > 0:
		sold.emit(kind, got)
	refresh()

static func _button(key: String) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(150, 60)
	b.add_theme_font_size_override("font_size", 24)
	return b
