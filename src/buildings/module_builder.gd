class_name ModuleBuilder
extends Node3D
## Construtor de módulos (separador "Construir" do DBG): escolhe um módulo do pack modular sci-fi
## (ou uma montagem pronta), vê-o em fantasma à frente do jogador numa grelha de 2 m, coloca, roda,
## muda de andar, desfaz, limpa e copia a montagem (lista de peças) para o clipboard.
## A primeira peça define a origem e a orientação da montagem (cima = cima do planeta ali).

const GRID := 2.0
const AHEAD := 7.0
const PREFABS := {"★ Casa do colono": "colonist_house", "★ Base": "outpost"}

var run: Node3D
var selected := "Wall_1"
var rotation_deg := 0.0
var storey := 0
var placed: Array[Dictionary] = [] # {m, p, r}
var _anchor: Node3D
var _ghost: MeshInstance3D
var _nodes: Array[Node3D] = []
var _list: ItemList
var _info: Label
## Modo construção: barra própria em baixo, ao centro (fora do painel DBG, que tapava a vista).
var building := false
var _bar: Control
var _bar_name: Label
var _palette := BuildingKit.BASE_PALETTE

func setup(p_run: Node3D) -> void:
	run = p_run
	if not DebugMenu.enabled:
		return
	_ghost = MeshInstance3D.new()
	# Fantasma semitransparente (material próprio: a transparência por objeto não funciona no
	# renderer Compatibility).
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.vertex_color_use_as_albedo = true
	gm.albedo_color = Color(1.0, 1.0, 1.0, 0.45)
	gm.no_depth_test = true
	_ghost.material_override = gm
	_ghost.visible = false
	add_child(_ghost)
	var tab := "DBG_TAB_BUILD"
	var enter := _btn("BUILD_ENTER", enter_mode)
	enter.custom_minimum_size = Vector2(0, 80)
	enter.add_theme_font_size_override("font_size", 28)
	DebugMenu.add_control(self, enter, tab)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 20)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	DebugMenu.add_control(self, _info, tab)
	var row1 := HBoxContainer.new()
	for spec in [["BUILD_PLACE", place], ["BUILD_ROTATE", rotate_90], ["BUILD_UNDO", undo]]:
		row1.add_child(_btn(spec[0], spec[1]))
	DebugMenu.add_control(self, row1, tab)
	var row2 := HBoxContainer.new()
	for spec in [["BUILD_UP", func() -> void: storey += 1], ["BUILD_DOWN", func() -> void: storey = maxi(storey - 1, 0)], ["BUILD_CLEAR", clear], ["BUILD_COPY", copy_layout]]:
		row2.add_child(_btn(spec[0], spec[1]))
	DebugMenu.add_control(self, row2, tab)
	DebugMenu.add_toggle(self, "BUILD_GHOST", false, func(on: bool) -> void: _ghost.visible = on, tab)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 520)
	_list.add_theme_font_size_override("font_size", 22)
	for k in PREFABS:
		_list.add_item(k)
	for m in BuildingKit.modules():
		_list.add_item(m)
	_list.item_selected.connect(func(i: int) -> void:
		selected = _list.get_item_text(i)
		_refresh_ghost())
	DebugMenu.add_control(self, _list, tab)
	_refresh_ghost()
	_make_bar()

## Barra do modo construção: em baixo ao centro, entre o joystick e os botões de ação.
func _make_bar() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_bar = PanelContainer.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.offset_bottom = -12
	_bar.visible = false
	layer.add_child(_bar)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_bar.add_child(col)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	row1.add_child(_small("◀", func() -> void: cycle(-1)))
	_bar_name = Label.new()
	_bar_name.custom_minimum_size = Vector2(260, 0)
	_bar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_name.add_theme_font_size_override("font_size", 22)
	row1.add_child(_bar_name)
	row1.add_child(_small("▶", func() -> void: cycle(1)))
	col.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	var place_btn := _small("BUILD_PLACE", place)
	place_btn.custom_minimum_size = Vector2(130, 64)
	row2.add_child(place_btn)
	row2.add_child(_small("⟳", rotate_90))
	row2.add_child(_small("▲", func() -> void: storey += 1))
	row2.add_child(_small("▼", func() -> void: storey = maxi(storey - 1, 0)))
	row2.add_child(_small("↶", undo))
	row2.add_child(_small("BUILD_COPY_SHORT", copy_layout))
	row2.add_child(_small("BUILD_EXIT", exit_mode))
	col.add_child(row2)

func _small(key: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(64, 64)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	return b

## Entra no modo construção: fecha o painel DBG, mostra a barra e a pré-visualização.
func enter_mode() -> void:
	building = true
	if DebugMenu.is_open():
		DebugMenu.toggle()
	if _bar:
		_bar.visible = true
	if _ghost:
		_ghost.visible = true

func exit_mode() -> void:
	building = false
	if _bar:
		_bar.visible = false
	if _ghost:
		_ghost.visible = false

## Escolhe o módulo anterior/seguinte (montagens prontas primeiro).
func cycle(step: int) -> void:
	var items: Array = PREFABS.keys() + BuildingKit.modules()
	var i := items.find(selected)
	selected = items[(i + step + items.size()) % items.size()]
	_refresh_ghost()

func _btn(key: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(0, 62)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	return b

func rotate_90() -> void:
	rotation_deg = fmod(rotation_deg + 90.0, 360.0)

## Peças do item selecionado (um módulo, ou todas as de uma montagem pronta), relativas ao cursor.
func _selected_parts() -> Array:
	if PREFABS.has(selected):
		return BuildingKit.colonist_house() if PREFABS[selected] == "colonist_house" else BuildingKit.outpost()
	return [{"m": selected, "p": Vector3.ZERO, "r": 0}]

func _refresh_ghost() -> void:
	if _ghost:
		_ghost.mesh = BuildingKit.bake(_selected_parts(), _palette)

## Referencial da montagem: o da primeira peça, ou um novo à frente do jogador.
func _frame() -> Transform3D:
	if _anchor:
		return _anchor.global_transform
	var c: Node3D = run.carrier_node()
	var up: Vector3 = (c.global_position - run.planet.global_position).normalized()
	var fwd: Vector3 = -run.camera.global_basis.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var x := up.cross(-fwd).normalized()
	var b := Basis(x, up, x.cross(up)).orthonormalized()
	var p: Vector3 = c.global_position + fwd * AHEAD
	var planet: Planet = run.planet
	var local: Vector3 = planet.to_local(p).normalized()
	return Transform3D(b, planet.to_global(planet.data.surface_point(local)))

## Posição (local da montagem) do cursor: à frente do jogador, presa à grelha.
func cursor_local() -> Vector3:
	var f := _frame()
	var c: Node3D = run.carrier_node()
	var fwd: Vector3 = -run.camera.global_basis.z
	var up: Vector3 = f.basis.y
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var target: Vector3 = f.affine_inverse() * (c.global_position + fwd * AHEAD)
	return Vector3(snappedf(target.x, GRID), storey * BuildingKit.STOREY, snappedf(target.z, GRID))

func place() -> void:
	if _anchor == null:
		# Calcular o referencial ANTES de criar a âncora (senão _frame() devolvia a própria âncora
		# ainda na origem — o centro do planeta — e as peças iam parar lá dentro).
		var frame := _frame()
		_anchor = Node3D.new()
		_anchor.name = "Assembly"
		add_child(_anchor)
		_anchor.global_transform = frame
	var at := cursor_local()
	for part in _selected_parts():
		var pp: Vector3 = Basis(Vector3.UP, deg_to_rad(rotation_deg)) * (part.p as Vector3) + at
		var rec := {"m": part.m, "p": pp, "r": fmod(float(part.get("r", 0.0)) + rotation_deg, 360.0)}
		placed.append(rec)
		var n := BuildingKit.build([{"m": rec.m, "p": Vector3.ZERO, "r": 0}], _palette)
		n.transform = BuildingKit.part_transform(rec)
		_anchor.add_child(n)
		_nodes.append(n)

func undo() -> void:
	if placed.is_empty():
		return
	placed.pop_back()
	_nodes.pop_back().queue_free()

func clear() -> void:
	placed.clear()
	_nodes.clear()
	if _anchor:
		_anchor.queue_free()
		_anchor = null

## Lista de peças em texto (GDScript), para colar no chat e virar uma montagem pronta.
func layout_text() -> String:
	var lines := []
	for p in placed:
		var v: Vector3 = p.p
		lines.append('{"m": "%s", "p": Vector3(%s, %s, %s), "r": %d},' % [p.m, snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01), int(p.r)])
	return "[\n" + "\n".join(lines) + "\n]"

func copy_layout() -> void:
	var t := layout_text()
	DisplayServer.clipboard_set(t)
	print(t)
	if run.deliveries:
		run.deliveries.hud.toast(tr("BUILD_COPIED") % placed.size())

func _process(_delta: float) -> void:
	if _info:
		_info.text = tr("BUILD_INFO") % [selected, int(rotation_deg), storey, placed.size()]
	if _bar_name and _bar and _bar.visible:
		_bar_name.text = tr("BUILD_INFO") % [selected, int(rotation_deg), storey, placed.size()]
	if _ghost and _ghost.visible and run:
		var f := _frame()
		_ghost.global_transform = f * Transform3D(Basis(Vector3.UP, deg_to_rad(rotation_deg)), cursor_local())
