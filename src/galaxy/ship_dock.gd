class_name ShipDock
extends Node
## Nave na base (F5 #48): aparece depois de vencer o boss, na praça (corredor do 3.º posto).
## Ação junto dela abre a partida (DepartDialog); `depart` avisa a cena para viajar.

signal depart

const HEIGHT := 5.0
const NEAR := 6.0
const PARK_M := 12.0

var run: Node3D
var ship: Node3D
var dialog: DepartDialog
var dialog_open := false
var _crew := ""
var _action := JumpBuffer.new()

func setup(p_run: Node3D, hud_layer: CanvasLayer) -> void:
	run = p_run
	dialog = DepartDialog.new()
	dialog.wallet = run.wallet
	dialog.visible = false
	hud_layer.add_child(dialog)
	dialog.chosen.connect(_on_choice)

## Mostra (ou esconde) a nave do tripulante ativo na praça.
func refresh() -> void:
	var show: bool = run.boss_fight.beaten
	if ship and (_crew != run.crew.active or not show):
		ship.queue_free()
		ship = null
	if not show or ship:
		return
	_crew = run.crew.active
	ship = Node3D.new()
	ship.name = "Ship"
	run.add_child(ship)
	var m: Node3D = (load("res://assets/kit/naves/Spaceship_" + _crew + ".gltf") as PackedScene).instantiate()
	ship.add_child(m)
	KitUtil.fit_height(m, HEIGHT)
	CelShading.apply(m)
	var d: PlanetData = run.planet.data
	var toward: Vector3 = d.post_doors[2 % d.post_doors.size()]
	var spot := d.toward_point(d.outpost_dir, toward, minf(d.plaza_radius_m, PARK_M))
	var away := toward - spot * toward.dot(spot)
	var b := SphereMath.basis_from_up(spot)
	var z := away.normalized()
	b = Basis(spot.cross(z).normalized(), spot, z).orthonormalized() if z.length() > 0.5 else b
	ship.global_transform = run.planet.global_transform * Transform3D(b, d.surface_point(spot))

func ship_position() -> Vector3:
	return ship.global_position if ship else Vector3.INF

func near_ship() -> bool:
	return ship != null and not run.in_vehicle() and run.player.global_position.distance_to(ship.global_position) < NEAR

func hint() -> String:
	return tr("HINT_SHIP") if near_ship() and not dialog_open else ""

func open() -> void:
	dialog_open = true
	dialog.open()
	run.touch.visible = false
	run.player.controllable = false

func close() -> void:
	dialog_open = false
	dialog.visible = false
	run._update_touch_visibility()
	if not run.in_vehicle():
		run.player.controllable = true

func _on_choice(choice: String) -> void:
	close()
	if choice == "stay":
		return
	if choice == "sell":
		for k in DepartDialog.LEFT_BEHIND:
			Market.sell(run.wallet, k)
	depart.emit()

func _physics_process(delta: float) -> void:
	if run == null:
		return
	_action.update(Input.is_action_pressed("action"), delta)
	if _action.consume() and near_ship() and not dialog_open and not run.morning_open:
		open()
