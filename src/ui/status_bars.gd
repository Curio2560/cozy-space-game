class_name StatusBars
extends VBoxContainer
## Barras de estado no HUD (vida do rover, vida e O₂ do astronauta…). Cada barra tem um nome
## e só aparece quando `show_bar` está ligado.

var _bars := {} # nome -> [HBoxContainer, ProgressBar]

func _ready() -> void:
	position = Vector2(24, 92)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)

func add_bar(id: String, label_key: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = label_key
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_outline_color", Color(0.14, 0.1, 0.22))
	l.add_theme_constant_override("outline_size", 6)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 22)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.1, 0.22, 0.7)
	bg.set_corner_radius_all(8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	row.add_child(bar)
	add_child(row)
	row.visible = false
	_bars[id] = [row, bar]

func set_value(id: String, value: float, max_value: float) -> void:
	var bar: ProgressBar = _bars[id][1]
	bar.max_value = max_value
	bar.value = value

func value(id: String) -> float:
	return (_bars[id][1] as ProgressBar).value

func show_bar(id: String, on: bool) -> void:
	(_bars[id][0] as Control).visible = on

func is_shown(id: String) -> bool:
	return (_bars[id][0] as Control).visible
