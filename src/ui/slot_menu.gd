class_name SlotMenu
extends PanelContainer
## Menu de um slot vazio do posto: lista os edifícios com o custo e o que fazem; tocar em
## Construir constrói (se houver dinheiro).

signal closed

var controller: OutpostController
var slot := -1
var _list: VBoxContainer
var _title: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(860, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	_title = Label.new()
	_title.text = "SLOT_MENU_TITLE"
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", CozyTheme.PEACH)
	_title.add_theme_color_override("font_outline_color", CozyTheme.INK)
	_title.add_theme_constant_override("outline_size", 8)
	v.add_child(_title)
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
	slot = i
	refresh()
	visible = true

func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var st: Outpost = controller.state
	if slot >= 0 and st.slots[slot].kind == "turret":
		_title.text = "BUILDING_TURRET"
		_turret_rows(st)
		return
	_title.text = "SLOT_MENU_TITLE"
	for kind in Outpost.ORDER:
		var b: Dictionary = Outpost.BUILDINGS[kind]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 22)
		l.text = "%s — %s\n%s" % [tr("BUILDING_" + kind.to_upper()), cost_text(b.cost), tr("BUILDING_" + kind.to_upper() + "_INFO")]
		row.add_child(l)
		var btn := Button.new()
		btn.text = "SLOT_BUILD"
		btn.custom_minimum_size = Vector2(190, 64)
		btn.add_theme_font_size_override("font_size", 24)
		btn.disabled = not controller.run.wallet.can_afford(b.cost)
		btn.pressed.connect(func() -> void:
			if controller.build(slot, kind):
				closed.emit())
		row.add_child(btn)
		_list.add_child(row)

## Torre construída: nível, o que faz, e o botão para melhorar.
func _turret_rows(st: Outpost) -> void:
	var lv := st.level(slot)
	var stats: Dictionary = Outpost.TURRET_LEVELS[lv - 1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 22)
	l.text = "%s\n%s" % [tr("TURRET_LEVEL") % lv, tr("TURRET_STATS") % [stats.damage / stats.interval, stats.range]]
	var cost := st.upgrade_cost(slot)
	if not cost.is_empty():
		var nxt: Dictionary = Outpost.TURRET_LEVELS[lv]
		l.text += "\n" + tr("TURRET_NEXT") % [lv + 1, cost_text(cost), nxt.damage / nxt.interval, nxt.range]
	row.add_child(l)
	var btn := Button.new()
	btn.text = "TURRET_UPGRADE" if not cost.is_empty() else "TURRET_MAX"
	btn.custom_minimum_size = Vector2(190, 64)
	btn.add_theme_font_size_override("font_size", 24)
	btn.disabled = cost.is_empty() or not controller.run.wallet.can_afford(cost)
	btn.pressed.connect(func() -> void:
		if controller.upgrade(slot):
			refresh())
	row.add_child(btn)
	_list.add_child(row)

static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append(("%d ¢" % cost[k]) if k == Wallet.CREDITS else ("%d %s" % [cost[k], TranslationServer.translate("RES_" + str(k).to_upper())]))
	return " + ".join(parts)
