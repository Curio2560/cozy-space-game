class_name MorningScreen
extends PanelContainer
## Ecrã da manhã (F4 #42): resumo da noite, escolher o tripulante, as 3 encomendas do dia e
## plantar nos talhões vazios. O relógio fica parado até "Começar o dia".

signal closed

var run: Node3D
var report := {}
var _body: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(1000, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	var start := Button.new()
	start.name = "Start"
	start.text = "MORNING_START"
	start.custom_minimum_size = Vector2(0, 70)
	start.add_theme_font_size_override("font_size", 28)
	start.pressed.connect(func() -> void: closed.emit())
	root.add_child(start)

func open(p_report: Dictionary) -> void:
	report = p_report
	refresh()
	visible = true

## Texto do resumo da noite (também para os testes).
static func summary_text(r: Dictionary) -> String:
	if r.is_empty():
		return ""
	var t := TranslationServer.translate("MORNING_WAVES") % [int(r.cleared), int(r.waves)]
	t += "  ·  " + TranslationServer.translate("MORNING_GAIN") % [int(r.credits), int(r.data)]
	if int(r.broken) > 0:
		t += "\n" + TranslationServer.translate("MORNING_BROKEN") % int(r.broken)
	elif float(r.damage) > 0.0:
		t += "\n" + TranslationServer.translate("MORNING_DAMAGED")
	if bool(r.perfect):
		t += "\n" + TranslationServer.translate("MORNING_PERFECT")
	return t

func refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	_title(tr("MORNING_TITLE") % run.cycle.day, 36)
	if not report.is_empty():
		_text(summary_text(report), 24, Color("3a9a5b") if bool(report.perfect) else CozyTheme.INK)
	# Tripulante do dia.
	_title(tr("MORNING_CREW"), 26)
	var crew_row := GridContainer.new()
	crew_row.columns = 2
	crew_row.add_theme_constant_override("h_separation", 8)
	crew_row.add_theme_constant_override("v_separation", 8)
	_body.add_child(crew_row)
	for m in Crew.MEMBERS:
		var b := Button.new()
		b.text = "%s %d" % [tr("CREW_" + m.to_upper()), run.crew.level(m)]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_size_override("font_size", 20)
		b.disabled = m == run.crew.active
		b.pressed.connect(func() -> void:
			run.crew.select(m)
			refresh())
		crew_row.add_child(b)
	# Encomendas do dia.
	_title(tr("MORNING_ORDERS"), 26)
	var s: DeliverySession = run.deliveries.session
	if s.active != null:
		_text(tr("MORNING_ORDER_TAKEN") % [s.colonist_name(s.active.from_post), s.colonist_name(s.active.to_post)], 22, CozyTheme.INK)
	else:
		for o in s.offers.slice(0, 3):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var l := Label.new()
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.add_theme_font_size_override("font_size", 21)
			l.text = "[%s]  %s → %s  ·  %d ¢" % [tr("KIND_" + o.kind.to_upper()), s.colonist_name(o.from_post), s.colonist_name(o.to_post), o.base_pay]
			row.add_child(l)
			var b := Button.new()
			b.text = "BOARD_ACCEPT"
			b.custom_minimum_size = Vector2(170, 56)
			b.add_theme_font_size_override("font_size", 22)
			b.disabled = not s.can_accept(o)
			b.pressed.connect(func() -> void:
				run.deliveries.accept(o)
				refresh())
			row.add_child(b)
			_body.add_child(row)
	# Quinta.
	var farm: Farm = run.farm.farm
	var empty := []
	for i in run.farm.plot_total():
		if farm.state(i) == "empty":
			empty.append(i)
	_title(tr("MORNING_FARM"), 26)
	if empty.is_empty():
		_text(tr("MORNING_FARM_FULL"), 22, CozyTheme.INK)
	else:
		var farm_row := HBoxContainer.new()
		farm_row.add_theme_constant_override("separation", 8)
		_body.add_child(farm_row)
		for crop in Farm.ORDER:
			var cost: int = int(Farm.CROPS[crop].seed) * empty.size()
			var b := Button.new()
			b.text = tr("MORNING_PLANT") % [tr("CROP_" + crop.to_upper()), empty.size(), cost]
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 60)
			b.add_theme_font_size_override("font_size", 19)
			b.disabled = run.wallet.credits() < cost
			b.pressed.connect(func() -> void:
				plant_all(crop)
				refresh())
			farm_row.add_child(b)

## Planta `crop` em todos os talhões vazios (enquanto houver dinheiro). Devolve quantos.
func plant_all(crop: String) -> int:
	var n := 0
	for i in run.farm.plot_total():
		if run.farm.farm.state(i) == "empty" and run.farm.farm.plant(i, crop, run.wallet):
			n += 1
	return n

func _title(t: String, size: int) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CozyTheme.PEACH)
	l.add_theme_color_override("font_outline_color", CozyTheme.INK)
	l.add_theme_constant_override("outline_size", 7)
	_body.add_child(l)

func _text(t: String, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_body.add_child(l)
