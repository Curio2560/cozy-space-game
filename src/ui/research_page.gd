class_name ResearchPage
extends VBoxContainer
## Separador "Pesquisa" do terminal (#51): a nave-mãe por rádio. Compras com dados de pesquisa
## que ficam de planeta para planeta.

var run: Node3D
var _head: Label
var _rows: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_head = Label.new()
	_head.add_theme_font_size_override("font_size", 22)
	_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_head)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	add_child(_rows)

func refresh() -> void:
	if run == null:
		return
	var r: Research = run.research
	_head.text = tr("RESEARCH_HEAD") % run.wallet.amount(Wallet.DATA)
	for c in _rows.get_children():
		c.queue_free()
	for line in Research.ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 22)
		var stars := "●".repeat(r.level(line)) + "○".repeat(r.max_level(line) - r.level(line))
		l.text = "%s  %s\n%s" % [tr("RES_LINE_" + line.to_upper()), stars, tr("RES_LINE_" + line.to_upper() + "_INFO")]
		row.add_child(l)
		var b := Button.new()
		var cost := r.next_cost(line)
		b.text = tr("UPG_MAX") if cost.is_empty() else SlotMenu.cost_text(cost)
		b.custom_minimum_size = Vector2(220, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = cost.is_empty() or not run.wallet.can_afford(cost)
		b.pressed.connect(func() -> void:
			if run.buy_research(line):
				refresh())
		row.add_child(b)
		_rows.add_child(row)
