extends CanvasLayer
## Menu DBG (autoload DebugMenu). Só existe de facto em builds debug; em release as funções
## não fazem nada. Mostra FPS sempre (canto superior direito) e um painel com controlos que
## cada cena regista com add_button/add_slider/add_toggle; os controlos desaparecem quando
## o nó dono sai da árvore.

signal force_touch_changed(on: bool)

var enabled := OS.is_debug_build()
var force_touch := false
var _panel: PanelContainer
var _items: VBoxContainer
var _fps: Label

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not enabled:
		return
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.position += Vector2(-12, 10)
	add_child(bar)
	_fps = Label.new()
	_fps.add_theme_font_size_override("font_size", 22)
	_fps.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps.add_theme_constant_override("outline_size", 6)
	bar.add_child(_fps)
	var btn := Button.new()
	btn.text = "DBG"
	btn.custom_minimum_size = Vector2(84, 52)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(toggle)
	bar.add_child(btn)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(420, 0)
	_panel.offset_top = 72
	_panel.visible = false
	add_child(_panel)
	var scroll := ScrollContainer.new()
	_panel.add_child(scroll)
	_items = VBoxContainer.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items.add_theme_constant_override("separation", 10)
	scroll.add_child(_items)
	var title := Label.new()
	title.text = "DBG_TITLE"
	title.add_theme_font_size_override("font_size", 26)
	_items.add_child(title)
	add_toggle(self, "DBG_TOUCH", force_touch, func(on: bool) -> void:
		force_touch = on
		force_touch_changed.emit(on))

func _process(_delta: float) -> void:
	if _fps:
		_fps.text = "%d fps" % Engine.get_frames_per_second()

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event.is_action_pressed("debug_toggle"):
		toggle()

func toggle() -> void:
	if _panel:
		_panel.visible = not _panel.visible

func is_open() -> bool:
	return _panel != null and _panel.visible

func item_count() -> int:
	return _items.get_child_count() - 1 if _items else 0 # sem o título

func add_button(owner_node: Node, label_key: String, on_press: Callable) -> Control:
	if not enabled:
		return null
	var b := Button.new()
	b.text = label_key
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(on_press)
	return _add(owner_node, b)

func add_toggle(owner_node: Node, label_key: String, value: bool, on_change: Callable) -> Control:
	if not enabled:
		return null
	var c := CheckButton.new()
	c.text = label_key
	c.button_pressed = value
	c.custom_minimum_size = Vector2(0, 56)
	c.add_theme_font_size_override("font_size", 22)
	c.toggled.connect(on_change)
	return _add(owner_node, c)

func add_slider(owner_node: Node, label_key: String, min_v: float, max_v: float, step: float, value: float, on_change: Callable) -> Control:
	if not enabled:
		return null
	var box := VBoxContainer.new()
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 20)
	box.add_child(lbl)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 44)
	box.add_child(s)
	var refresh := func(v: float) -> void: lbl.text = "%s: %s" % [tr(label_key), str(snappedf(v, step))]
	refresh.call(value)
	s.value_changed.connect(func(v: float) -> void:
		refresh.call(v)
		on_change.call(v))
	return _add(owner_node, box)

func _add(owner_node: Node, c: Control) -> Control:
	_items.add_child(c)
	if owner_node != self:
		owner_node.tree_exiting.connect(c.queue_free, CONNECT_ONE_SHOT)
	return c
