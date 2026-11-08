class_name CrewPage
extends VBoxContainer
## Separador "Tripulação" do terminal: os 4 astronautas, nível, XP, vantagem e Escolher.

var run: Node3D
var _rows: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	add_child(_rows)

func refresh() -> void:
	if run == null:
		return
	var c: Crew = run.crew
	for ch in _rows.get_children():
		ch.queue_free()
	for m in Crew.MEMBERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 22)
		var next := c.xp_to_next(m)
		l.text = "%s · %s %d%s\n%s" % [tr("CREW_" + m.to_upper()), tr("CREW_LEVEL"), c.level(m), ("" if next == 0 else "  (" + tr("CREW_NEXT") % next + ")"), tr("CREW_" + m.to_upper() + "_PERK")]
		if m == c.active:
			l.add_theme_color_override("font_color", Color("3a9a5b"))
		row.add_child(l)
		var b := Button.new()
		b.text = "CREW_ACTIVE" if m == c.active else "CREW_SELECT"
		b.custom_minimum_size = Vector2(190, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = m == c.active
		b.pressed.connect(func() -> void:
			if c.select(m):
				run.autosave()
				refresh())
		row.add_child(b)
		_rows.add_child(row)
