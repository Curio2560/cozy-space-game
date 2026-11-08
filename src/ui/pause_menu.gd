class_name PauseMenu
extends Control
## Menu de pausa em estilo cel-shaded (painel creme com contorno e sombra, fonte Matcha).
## Pausa o jogo ao abrir; os botões emitem sinais para a cena decidir o que fazer.

signal resumed
signal new_planet
signal quit_to_menu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(CozyTheme.INK, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var title := Label.new()
	title.text = "PAUSE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", CozyTheme.PEACH)
	title.add_theme_color_override("font_outline_color", CozyTheme.INK)
	title.add_theme_constant_override("outline_size", 12)
	col.add_child(title)
	_item(col, "PAUSE_RESUME", func() -> void:
		close()
		resumed.emit())
	_item(col, "PAUSE_NEW_PLANET", func() -> void:
		close()
		new_planet.emit())
	_item(col, "PAUSE_TUTORIAL", func() -> void:
		close()
		tutorial_again.emit())
	_item(col, "PAUSE_NEW_GAME", func() -> void: _confirm_new_game())
	_item(col, "PAUSE_LANGUAGE", func() -> void: Settings.cycle_locale())
	_item(col, "PAUSE_EXIT", func() -> void:
		close()
		quit_to_menu.emit())

signal new_game
signal tutorial_again

func _confirm_new_game() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = tr("NEW_GAME_CONFIRM")
	dlg.ok_button_text = tr("NEW_GAME_YES")
	dlg.cancel_button_text = tr("NEW_GAME_NO")
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		close()
		new_game.emit())
	dlg.visibility_changed.connect(func() -> void:
		if not dlg.visible:
			dlg.queue_free())
	dlg.popup_centered()

func _item(col: VBoxContainer, key: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(380, 70)
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(action)
	col.add_child(b)
	return b

func open() -> void:
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func is_open() -> bool:
	return visible
