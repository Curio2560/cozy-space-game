class_name PauseMenu
extends Control
## Menu de pausa com a moldura néon do pack Sci-Fi Game UI e texto traduzido.
## Pausa o jogo ao abrir; os botões emitem sinais para a cena decidir o que fazer.

signal resumed
signal new_planet
signal quit_to_menu

const FRAME := preload("res://assets/ui/scifi/pause_frame.png")
const UNDERLINE := preload("res://assets/ui/scifi/underline.png")

var _lang_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var frame := TextureRect.new()
	frame.texture = FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_top = 24
	frame.offset_bottom = -24
	add_child(frame)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var title := Label.new()
	title.text = "PAUSE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", NeonTheme.CYAN)
	col.add_child(title)
	_item(col, "PAUSE_RESUME", func() -> void: close(); resumed.emit())
	_item(col, "PAUSE_NEW_PLANET", func() -> void: close(); new_planet.emit())
	_lang_button = _item(col, "PAUSE_LANGUAGE", func() -> void: Settings.cycle_locale())
	_item(col, "PAUSE_EXIT", func() -> void: close(); quit_to_menu.emit())

func _item(col: VBoxContainer, key: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.flat = true
	b.custom_minimum_size = Vector2(320, 64)
	b.add_theme_font_size_override("font_size", 38)
	b.pressed.connect(action)
	col.add_child(b)
	var line := TextureRect.new()
	line.texture = UNDERLINE
	line.custom_minimum_size = Vector2(260, 8)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(line)
	return b

func open() -> void:
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func is_open() -> bool:
	return visible
