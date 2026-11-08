extends CanvasLayer
## Menu DBG (autoload DebugMenu). Só existe de facto em builds debug; em release as funções
## não fazem nada. Mostra FPS sempre (canto superior direito) e um painel ao centro do ecrã
## (ao alcance do dedo) com separadores: cada cena regista controlos com add_button/add_slider/
## add_toggle/add_label/add_control; os controlos desaparecem quando o nó dono sai da árvore.
## Botões ▲▼ grandes dentro do painel para subir/descer sem ir à borda do ecrã.

signal force_touch_changed(on: bool)

const TABS := ["DBG_TAB_GENERAL", "DBG_TAB_WORLD", "DBG_TAB_PLAYER", "DBG_TAB_ROVER", "DBG_TAB_CREATURES", "DBG_TAB_NIGHT", "DBG_TAB_BUILD"]
const GENERAL := "DBG_TAB_GENERAL"

var enabled := OS.is_debug_build()
var force_touch := false
## Separador onde vão os próximos controlos registados (sem `tab` explícito).
var default_tab := GENERAL
var _panel: PanelContainer
var _tabs: TabContainer
var _lists := {} # separador -> VBoxContainer
var _scrolls := {} # separador -> ScrollContainer
var _fps: Label
var _labels: Array = [] # [Label, Callable]

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
	_fps.add_theme_color_override("font_color", CozyTheme.CREAM)
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
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(820, 560)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	# Coluna de navegação à esquerda: subir, descer, fechar (grandes, ao alcance do polegar).
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	row.add_child(nav)
	for spec in [["▲", -260.0], ["▼", 260.0]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(84, 150)
		b.add_theme_font_size_override("font_size", 40)
		var amount: float = spec[1]
		b.pressed.connect(func() -> void: _scroll_by(amount))
		nav.add_child(b)
	var close := Button.new()
	close.icon = CozyTheme.icon(CozyTheme.ICON_CLOSE)
	close.expand_icon = true
	close.custom_minimum_size = Vector2(84, 84)
	close.pressed.connect(toggle)
	nav.add_child(close)
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_tabs)
	for t in TABS:
		var sc := ScrollContainer.new()
		sc.name = t
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.scroll_deadzone = 12 # arrastar com o dedo em qualquer sítio da lista
		_tabs.add_child(sc)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 10)
		sc.add_child(v)
		_lists[t] = v
		_scrolls[t] = sc
	for i in TABS.size():
		_tabs.set_tab_title(i, tr(TABS[i]))
	add_toggle(self, "DBG_TOUCH", force_touch, func(on: bool) -> void:
		force_touch = on
		force_touch_changed.emit(on))
	add_slider(self, "DBG_TIME_SCALE", 0.25, 4.0, 0.25, Engine.time_scale, func(v: float) -> void: Engine.time_scale = v)
	add_slider(self, "DBG_RENDER_SCALE", 0.5, 1.0, 0.05, get_viewport().scaling_3d_scale, func(v: float) -> void:
		get_tree().root.scaling_3d_scale = v)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _tabs:
		for i in TABS.size():
			_tabs.set_tab_title(i, tr(TABS[i]))

func _scroll_by(amount: float) -> void:
	var sc: ScrollContainer = _tabs.get_current_tab_control()
	if sc:
		sc.scroll_vertical = int(sc.scroll_vertical + amount)

func _process(_delta: float) -> void:
	if _fps:
		_fps.text = stats_text()
	_labels = _labels.filter(func(pair: Array) -> bool: return is_instance_valid(pair[0]) and (pair[1] as Callable).is_valid())
	for pair in _labels:
		(pair[0] as Label).text = str((pair[1] as Callable).call())

## FPS, draw calls e triângulos do último frame (para medir no telemóvel).
static func stats_text() -> String:
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var tris := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	return "%d fps · %d dc · %dk tri" % [Engine.get_frames_per_second(), dc, tris / 1000]

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event.is_action_pressed("debug_toggle"):
		toggle()

func toggle() -> void:
	if _panel:
		_panel.visible = not _panel.visible

func is_open() -> bool:
	return _panel != null and _panel.visible

## Abre o painel num separador (p. ex. "DBG_TAB_BUILD").
func show_tab(tab: String) -> void:
	if _tabs and TABS.has(tab):
		_tabs.current_tab = TABS.find(tab)

func item_count(tab := "") -> int:
	if not _lists:
		return 0
	if tab != "":
		return (_lists[tab] as VBoxContainer).get_child_count()
	var n := 0
	for t in _lists:
		n += (_lists[t] as VBoxContainer).get_child_count()
	return n - 3 # sem os controlos do próprio menu (toque, tempo, resolução)

func add_button(owner_node: Node, label_key: String, on_press: Callable, tab := "") -> Control:
	if not enabled:
		return null
	var b := Button.new()
	b.text = label_key
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(on_press)
	return _add(owner_node, b, tab)

func add_toggle(owner_node: Node, label_key: String, value: bool, on_change: Callable, tab := "") -> Control:
	if not enabled:
		return null
	var c := CheckButton.new()
	c.text = label_key
	c.button_pressed = value
	c.custom_minimum_size = Vector2(0, 56)
	c.add_theme_font_size_override("font_size", 22)
	c.toggled.connect(on_change)
	return _add(owner_node, c, tab)

func add_slider(owner_node: Node, label_key: String, min_v: float, max_v: float, step: float, value: float, on_change: Callable, tab := "") -> Control:
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
	s.custom_minimum_size = Vector2(0, 48)
	box.add_child(s)
	var refresh := func(v: float) -> void: lbl.text = "%s: %s" % [tr(label_key), str(snappedf(v, step))]
	refresh.call(value)
	s.value_changed.connect(func(v: float) -> void:
		refresh.call(v)
		on_change.call(v))
	return _add(owner_node, box, tab)

## Linha de texto atualizada a cada frame com o resultado de `getter`.
func add_label(owner_node: Node, getter: Callable, tab := "") -> Control:
	if not enabled:
		return null
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 20)
	var pair := [l, getter]
	_labels.append(pair)
	# Deixar de chamar o getter logo que o dono sai (não esperar pelo queue_free da linha).
	if owner_node != self:
		owner_node.tree_exiting.connect(func() -> void: _labels.erase(pair), CONNECT_ONE_SHOT)
	return _add(owner_node, l, tab)

## Acrescenta um controlo qualquer (p. ex. a lista de módulos do separador Construir).
func add_control(owner_node: Node, c: Control, tab := "") -> Control:
	if not enabled:
		return null
	return _add(owner_node, c, tab)

func _add(owner_node: Node, c: Control, tab: String) -> Control:
	var t := tab if tab != "" else default_tab
	if not _lists.has(t):
		t = GENERAL
	(_lists[t] as VBoxContainer).add_child(c)
	if owner_node != self:
		owner_node.tree_exiting.connect(c.queue_free, CONNECT_ONE_SHOT)
	return c
