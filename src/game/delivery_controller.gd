class_name DeliveryController
extends Node
## Liga a DeliverySession à cena do planeta: nomes dos colonos, quadro de encomendas no
## posto avançado, caixa para apanhar, farol no destino, seta e relógio no HUD.

const BOARD_RADIUS := 11.0 # distância ao centro do posto avançado para abrir o quadro
const PICKUP_RADIUS := 5.0
const DELIVER_RADIUS := 6.5
const CRATE := "pickups/Pickup_Crate"

var run: Node3D # planet_run
var wallet: Wallet
var session: DeliverySession
var board: DeliveryBoard
var hud: DeliveryHud
var board_open := false
## Criatura que fugiu com a caixa (estado STOLEN).
var thief: Node3D
const RECOVER_RADIUS := 2.8

var _crate: Node3D
var _beacon: MeshInstance3D
var _labels: Array[Label3D] = []
var _action := JumpBuffer.new()

func setup(p_run: Node3D, p_wallet: Wallet, hud_layer: CanvasLayer) -> void:
	run = p_run
	wallet = p_wallet
	hud = DeliveryHud.new()
	hud_layer.add_child(hud)
	board = DeliveryBoard.new()
	board.visible = false
	hud_layer.add_child(board)
	board.accepted.connect(_on_accept)
	board.closed.connect(close_board)
	wallet.changed.connect(_update_credits)
	_crate = Node3D.new()
	_crate.name = "Crate"
	var m: Node3D = (load("res://assets/kit/" + CRATE + ".gltf") as PackedScene).instantiate()
	_crate.add_child(m)
	KitUtil.fit_height(m, 0.7)
	CelShading.apply(m)
	run.add_child(_crate)
	_beacon = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.9
	cyl.height = 30.0
	_beacon.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.78, 0.34, 0.45)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon.material_override = mat
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	run.add_child(_beacon)
	_update_credits()

## Chamado sempre que se gera um planeta novo.
func start_planet(data: PlanetData) -> void:
	var n := data.posts.size()
	var dist: Array = []
	for i in n:
		var row: Array = []
		for j in n:
			row.append(data.arc_m(data.posts[i], data.posts[j]))
		dist.append(row)
	session = DeliverySession.new(wallet, dist, data.seed)
	board.session = session
	for l in _labels:
		l.queue_free()
	_labels.clear()
	for i in n:
		var l := Label3D.new()
		l.text = session.colonist_name(i)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 96
		l.pixel_size = 0.012
		l.outline_size = 24
		l.modulate = Color("fff6ea")
		l.outline_modulate = Color(0.14, 0.1, 0.22)
		l.no_depth_test = false
		run.add_child(l)
		l.global_position = post_position(i) + data.posts[i] * 4.6
		_labels.append(l)
	close_board()

func post_position(i: int) -> Vector3:
	var d: PlanetData = run.planet.data
	return run.planet.to_global(d.surface_point(d.posts[i]))

func outpost_position() -> Vector3:
	var d: PlanetData = run.planet.data
	return run.planet.to_global(d.surface_point(d.outpost_dir))

func carrier() -> Node3D:
	return run.rover if run.driving else run.player

func near_board() -> bool:
	return carrier().global_position.distance_to(outpost_position()) < BOARD_RADIUS

func open_board() -> void:
	board_open = true
	board.refresh()
	board.visible = true
	run.touch.visible = false
	run.player.controllable = false

func close_board() -> void:
	board_open = false
	board.visible = false
	run._update_touch_visibility()
	if not run.driving:
		run.player.controllable = true

func accept(o: DeliveryOrder) -> bool:
	var ok := session.accept(o)
	if ok:
		hud.toast(tr("TOAST_ACCEPTED") % session.colonist_name(o.from_post))
	return ok

func _on_accept(o: DeliveryOrder) -> void:
	if accept(o):
		close_board()

func hint() -> String:
	if board_open or session == null:
		return ""
	if near_board() and session.active == null:
		return tr("HINT_BOARD")
	return ""

func _physics_process(delta: float) -> void:
	if session == null:
		return
	_action.update(Input.is_action_pressed("action"), delta)
	if _action.consume() and not board_open and near_board():
		open_board()
	session.tick(delta)
	var pos := carrier().global_position
	var o := session.active
	if o and o.state == DeliveryOrder.State.ACCEPTED and pos.distance_to(post_position(o.from_post)) < PICKUP_RADIUS:
		session.pick_up()
		hud.toast(tr("TOAST_PICKED"))
	elif o and o.state == DeliveryOrder.State.DROPPED and pos.distance_to(o.drop_position) < RECOVER_RADIUS:
		session.recover()
		hud.toast(tr("TOAST_RECOVERED"))
	elif o and o.state == DeliveryOrder.State.CARRYING and pos.distance_to(post_position(o.to_post)) < DELIVER_RADIUS:
		var late := o.is_late()
		var paid := session.deliver()
		hud.toast((tr("TOAST_DELIVERED_LATE") if late else tr("TOAST_DELIVERED")) % paid)
	_update_world(delta)
	_update_hud()

func _update_world(delta: float) -> void:
	var o := session.active
	var target := session.target_post()
	_beacon.visible = target >= 0
	if target >= 0:
		var up: Vector3 = run.planet.data.posts[target]
		_beacon.global_transform = Transform3D(SphereMath.basis_from_up(run.planet.global_basis * up), post_position(target) + up * 15.0)
	_crate.visible = o != null
	if o == null:
		return
	if o.state == DeliveryOrder.State.ACCEPTED:
		var up: Vector3 = run.planet.data.posts[o.from_post]
		var p := post_position(o.from_post) + up * 1.2 + SphereMath.basis_from_up(up).z * 3.0
		_crate.global_transform = Transform3D(SphereMath.basis_from_up(up, Time.get_ticks_msec() * 0.002), p)
	elif o.state == DeliveryOrder.State.STOLEN and is_instance_valid(thief):
		var tu: Vector3 = (thief.global_position - run.planet.global_position).normalized()
		_crate.global_transform = Transform3D(thief.global_basis.orthonormalized(), thief.global_position + tu * 1.9)
	elif o.state == DeliveryOrder.State.DROPPED:
		var du: Vector3 = (o.drop_position - run.planet.global_position).normalized()
		_crate.global_transform = Transform3D(SphereMath.basis_from_up(du, Time.get_ticks_msec() * 0.002), o.drop_position + du * 0.3)
	else:
		var c := carrier()
		var up: Vector3 = (c.global_position - run.planet.global_position).normalized()
		var lift := 2.2 if run.driving else 2.1
		_crate.global_transform = Transform3D(c.global_basis.orthonormalized(), c.global_position + up * lift)

func _update_hud() -> void:
	var o := session.active
	hud.arrow.visible = o != null
	if o == null:
		hud.order_label.text = ""
		return
	var target := session.target_post()
	var c := carrier()
	var up: Vector3 = (c.global_position - run.planet.global_position).normalized()
	var tp := post_position(target)
	if o.state == DeliveryOrder.State.STOLEN and is_instance_valid(thief):
		tp = thief.global_position
	elif o.state == DeliveryOrder.State.DROPPED:
		tp = o.drop_position
	hud.arrow.set_angle(NavArrow.angle_to_target(c.global_position, up, run.camera.global_basis, tp))
	var dist := int(c.global_position.distance_to(tp))
	if o.state == DeliveryOrder.State.STOLEN:
		hud.order_label.text = tr("HUD_THIEF") % [dist, DeliveryHud.format_time(o.remaining())]
	elif o.state == DeliveryOrder.State.DROPPED:
		hud.order_label.text = tr("HUD_DROPPED") % [dist, DeliveryHud.format_time(o.remaining())]
	elif o.state == DeliveryOrder.State.ACCEPTED:
		hud.order_label.text = tr("HUD_PICKUP") % [session.colonist_name(target), dist]
	else:
		hud.order_label.text = tr("HUD_DELIVER") % [session.colonist_name(target), dist, DeliveryHud.format_time(o.remaining())]
		hud.order_label.add_theme_color_override("font_color", Color("ff9f7a") if o.is_late() else Color("fff6ea"))

func _update_credits() -> void:
	if hud and hud.credits_label:
		hud.credits_label.text = "%d ¢" % wallet.credits()
