class_name OutpostController
extends Node
## Posto avançado do jogador: o terminal à porta da base (menu com separadores) e, nas issues
## seguintes, os slots de edifícios, a quinta, os upgrades e a tripulação.

const TERMINAL_RADIUS := 3.2
## Terminal no espaço da base (a porta da base é +Z): ao lado da porta dupla.
const TERMINAL_LOCAL := Vector3(3.0, 0.0, 5.6)

var run: Node3D
var menu: TerminalMenu
var menu_open := false
var _action := JumpBuffer.new()

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
	run._update_touch_visibility()
	if not run.driving:
		run.player.controllable = true

func hint() -> String:
	if menu_open:
		return ""
	return tr("HINT_TERMINAL") if near_terminal() else ""

func _physics_process(delta: float) -> void:
	if run == null:
		return
	_action.update(Input.is_action_pressed("action"), delta)
	if _action.consume() and not menu_open and not run.deliveries.board_open and near_terminal():
		open_menu()
