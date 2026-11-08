class_name OutpostController
extends Node
## Posto avançado do jogador: o terminal à porta da base (menu com separadores) e os slots de
## edifícios à volta da praça (regras em Outpost; aqui só cena, menus e input).

const TERMINAL_RADIUS := 3.2
## Terminal no espaço da base (a porta da base é +Z): ao lado da porta dupla.
const TERMINAL_LOCAL := Vector3(3.0, 0.0, 5.6)

var run: Node3D
var menu: TerminalMenu
var menu_open := false
var _action := JumpBuffer.new()
var state := Outpost.new()
var slot_menu: SlotMenu
var build_page: OutpostPage
const SLOT_RADIUS := 3.6
## Visual de cada edifício: modelo do kit (altura em m) ou montagem do pack sci-fi.
const VISUALS := {
	"miner": {"parts": [{"m": "Props_Laser", "p": Vector3(0, 0.0, 0), "r": 0}, {"m": "Props_ContainerFull", "p": Vector3(1.2, 0, -1.1), "r": 90}]},
	"lab": {"kit": "base/House_Cylinder", "h": 3.6},
	"research": {"kit": "base/GeodesicDome", "h": 3.4},
	"solar": {"kit": "base/SolarPanel_Ground", "h": 2.0},
	"storage": {"parts": [{"m": "Props_ContainerFull", "p": Vector3(-0.8, 0, 0), "r": 0}, {"m": "Props_CrateLong", "p": Vector3(1.1, 0, 0.9), "r": 90}, {"m": "Props_Crate", "p": Vector3(1.1, 0, -1.0), "r": 15}]},
}
var _slot_nodes: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _label_t := 0.0

func setup(p_run: Node3D, hud_layer: CanvasLayer) -> void:
	run = p_run
	menu = TerminalMenu.new()
	menu.wallet = run.wallet
	menu.visible = false
	hud_layer.add_child(menu)
	menu.closed.connect(close_menu)
	menu.sold.connect(func(kind: String, got: int) -> void:
		run.deliveries.hud.toast(tr("TOAST_SOLD") % [got, tr("RES_" + kind.to_upper())])
		run.autosave())
	build_page = OutpostPage.new()
	build_page.controller = self
	menu.add_page("TERMINAL_TAB_BUILD", build_page, true)
	slot_menu = SlotMenu.new()
	slot_menu.controller = self
	slot_menu.visible = false
	hud_layer.add_child(slot_menu)
	slot_menu.closed.connect(close_menu)

## Planeta novo: posto vazio (o posto recomeça em cada planeta) e slots desenhados.
func start_planet() -> void:
	state = Outpost.new()
	rebuild()

## Repõe o posto de um save.
func load_state(d: Dictionary) -> void:
	state.from_dict(d)
	rebuild()

## Slots disponíveis neste planeta (o gerador garante MAX_SLOTS, mas nunca confiar).
func slot_total() -> int:
	return mini(state.slot_count, run.planet.data.outpost_slots.size())

## (Re)cria plataformas, edifícios e letreiros de todos os slots abertos.
func rebuild() -> void:
	for n in _slot_nodes:
		if is_instance_valid(n):
			n.free() # já: os nós novos têm os mesmos nomes
	_slot_nodes.clear()
	_labels.clear()
	var d: PlanetData = run.planet.data
	for i in slot_total():
		var holder := Node3D.new()
		holder.name = "Slot%d" % i
		run.planet.add_child(holder)
		_slot_nodes.append(holder)
		var dir := d.outpost_slots[i]
		var pad: Node3D = run.planet._place_building(_pad_parts(), BuildingKit.BASE_PALETTE, dir, "Pad%d" % i, d.outpost_dir)
		pad.reparent(holder)
		var kind: String = state.slots[i].kind
		if kind != "":
			var v: Dictionary = VISUALS[kind]
			var b: Node3D
			if v.has("kit"):
				b = run.planet._place_model(v.kit, dir, float(v.h), "B%d" % i, d.outpost_dir)
				# A colisão do modelo vai para o corpo do planeta: passá-la para um corpo do slot,
				# para sair com ele quando se redesenha.
				var body := StaticBody3D.new()
				body.name = "Body"
				holder.add_child(body)
				var cs: Node = run.planet.body.get_child(run.planet.body.get_child_count() - 1)
				cs.reparent(body, true)
			else:
				b = run.planet._place_building(v.parts, BuildingKit.BASE_PALETTE, dir, "B%d" % i, d.outpost_dir)
			b.reparent(holder)
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 48
		l.outline_size = 12
		l.pixel_size = 0.01
		l.no_depth_test = false
		holder.add_child(l)
		l.global_position = run.planet.to_global(d.surface_point(dir) + dir * 4.6)
		_labels.append(l)
	_update_labels()

static func _pad_parts() -> Array:
	var out := []
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			out.append({"m": "FloorTile_Basic", "p": Vector3(x, 0, z), "r": 0})
	return out

func _update_labels() -> void:
	for i in _labels.size():
		var s: Dictionary = state.slots[i]
		var l := _labels[i]
		if s.kind == "":
			l.text = tr("SLOT_EMPTY")
			l.modulate = Color(1, 1, 1, 0.75)
		else:
			var b: Dictionary = Outpost.BUILDINGS[s.kind]
			var line := tr("BUILDING_" + s.kind.to_upper())
			if b.produces != "":
				line += "\n%s %d/%d" % [tr("RES_" + str(b.produces).to_upper()), s.stored, state.capacity()]
			l.text = line
			l.modulate = Color("ffc857") if int(s.stored) >= state.capacity() else Color.WHITE

## Slot aberto mais perto do jogador (a pé), ou -1.
func nearest_slot() -> int:
	if run.driving or run.planet.data == null:
		return -1
	var best := -1
	var best_d := SLOT_RADIUS
	var d: PlanetData = run.planet.data
	for i in slot_total():
		var p: Vector3 = run.planet.to_global(d.surface_point(d.outpost_slots[i]))
		var dist: float = run.player.global_position.distance_to(p)
		if dist < best_d:
			best_d = dist
			best = i
	return best

## Constrói `kind` no slot `i` (paga, redesenha, guarda).
func build(i: int, kind: String) -> bool:
	if not state.build(i, kind, run.wallet):
		return false
	rebuild()
	run.deliveries.hud.toast(tr("TOAST_BUILT") % tr("BUILDING_" + kind.to_upper()))
	run.autosave()
	return true

func collect(i: int) -> int:
	var n := state.collect(i, run.wallet)
	if n > 0:
		var res: String = Outpost.BUILDINGS[state.slots[i].kind].produces
		run.deliveries.hud.toast(tr("TOAST_COLLECTED") % [n, tr("RES_" + res.to_upper())])
		_update_labels()
		run.autosave()
	return n

func collect_all() -> int:
	var n := state.collect_all(run.wallet)
	if n > 0:
		run.deliveries.hud.toast(tr("TOAST_COLLECTED_ALL") % n)
		_update_labels()
		run.autosave()
	return n

func open_slot_menu(i: int) -> void:
	menu_open = true
	slot_menu.open(i)
	run.touch.visible = false
	run.player.controllable = false

func _process(delta: float) -> void:
	if run == null or run.wallet == null:
		return
	state.tick(delta, run.wallet)
	_label_t -= delta
	if _label_t <= 0.0:
		_label_t = 0.25
		_update_labels()

## Posição (global) do terminal no planeta atual.
func terminal_position() -> Vector3:
	var base: Node3D = run.planet.get_node_or_null("Outpost")
	if base == null:
		return Vector3.INF
	return base.global_transform * TERMINAL_LOCAL

func near_terminal() -> bool:
	return not run.driving and run.player.global_position.distance_to(terminal_position()) < TERMINAL_RADIUS

func open_menu() -> void:
	menu_open = true
	menu.refresh()
	menu.visible = true
	run.touch.visible = false
	run.player.controllable = false

func close_menu() -> void:
	menu_open = false
	menu.visible = false
	slot_menu.visible = false
	if run.farm:
		run.farm.menu.visible = false
	run._update_touch_visibility()
	if not run.driving:
		run.player.controllable = true

func hint() -> String:
	if menu_open:
		return ""
	if near_terminal():
		return tr("HINT_TERMINAL")
	var i := nearest_slot()
	if i < 0:
		return run.farm.hint() if run.farm else ""
	var s: Dictionary = state.slots[i]
	if s.kind == "":
		return tr("HINT_SLOT_BUILD")
	if int(s.stored) > 0:
		return tr("HINT_SLOT_COLLECT") % [s.stored, tr("RES_" + str(Outpost.BUILDINGS[s.kind].produces).to_upper())]
	return ""

func _physics_process(delta: float) -> void:
	if run == null:
		return
	_action.update(Input.is_action_pressed("action"), delta)
	if _action.consume() and not menu_open and not run.deliveries.board_open:
		if near_terminal():
			open_menu()
		elif run.farm and run.farm.act():
			pass
		else:
			var i := nearest_slot()
			if i >= 0:
				if state.is_empty(i):
					open_slot_menu(i)
				else:
					collect(i)
