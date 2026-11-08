class_name OutpostPage
extends VBoxContainer
## Separador "Construir" do terminal: energia, estado de cada slot e "Recolher tudo".
## (Para construir, vai-se ao slot e carrega-se em Ação.)

var controller: OutpostController
var _energy: Label
var _rows: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_energy = Label.new()
	_energy.add_theme_font_size_override("font_size", 26)
	add_child(_energy)
	var tip := Label.new()
	tip.text = "OUTPOST_TIP"
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", Color(CozyTheme.INK, 0.65))
	add_child(tip)
	_rows = VBoxContainer.new()
	add_child(_rows)
	var all := Button.new()
	all.text = "OUTPOST_COLLECT_ALL"
	all.custom_minimum_size = Vector2(0, 60)
	all.add_theme_font_size_override("font_size", 24)
	all.pressed.connect(func() -> void:
		controller.collect_all()
		refresh())
	add_child(all)

func refresh() -> void:
	var st := controller.state
	_energy.text = tr("OUTPOST_ENERGY") % [st.energy_supply(), st.energy_demand()] + ("" if st.power_factor() >= 1.0 else "  ·  " + tr("OUTPOST_LOW_POWER"))
	for c in _rows.get_children():
		c.queue_free()
	for i in controller.slot_total():
		var s: Dictionary = st.slots[i]
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 22)
		if s.kind == "":
			l.text = "%d. %s" % [i + 1, tr("SLOT_EMPTY")]
		else:
			var b: Dictionary = Outpost.BUILDINGS[s.kind]
			l.text = "%d. %s" % [i + 1, tr("BUILDING_" + s.kind.to_upper())]
			if b.produces != "":
				l.text += "  ·  %s %d/%d" % [tr("RES_" + str(b.produces).to_upper()), s.stored, st.capacity()]
		_rows.add_child(l)
