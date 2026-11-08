class_name FarmController
extends Node
## Cena da quinta: talhões de terra junto ao posto, plantas a crescer (escala com o progresso),
## Ação para plantar (menu de culturas) e colher. Regras em Farm.

const PLOT_RADIUS := 3.0
## Planta por cultura (modelos do kit) e altura quando pronta.
const PLANT := {"fast": ["natureza/Plant_1", 0.9], "mid": ["natureza/Plant_2", 1.2], "slow": ["natureza/Plant_3", 1.5]}
const SOIL := Color("6b4a33")

var run: Node3D
var farm := Farm.new()
var menu: CropMenu
var _nodes: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _plants: Array[Node3D] = []
var _shown_state: Array[String] = []
var _t := 0.0

func setup(p_run: Node3D, hud_layer: CanvasLayer) -> void:
	run = p_run
	menu = CropMenu.new()
	menu.controller = self
	menu.visible = false
	hud_layer.add_child(menu)
	menu.closed.connect(func() -> void: run.outpost.close_menu())

func start_planet() -> void:
	farm = Farm.new()
	rebuild()

func load_state(d: Dictionary) -> void:
	farm.from_dict(d)
	rebuild()

func plot_total() -> int:
	return mini(Farm.PLOTS, run.planet.data.farm_plots.size())

func rebuild() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	_labels.clear()
	_plants.clear()
	_shown_state.clear()
	var d: PlanetData = run.planet.data
	for i in plot_total():
		var dir := d.farm_plots[i]
		var holder := Node3D.new()
		holder.name = "Plot%d" % i
		run.planet.add_child(holder)
		holder.transform = Transform3D(run.planet._facing_basis(dir, d.outpost_dir), d.surface_point(dir))
		_nodes.append(holder)
		var soil := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.2, 0.25, 3.2)
		soil.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = SOIL
		mat.roughness = 1.0
		soil.material_override = mat
		soil.position.y = 0.05
		holder.add_child(soil)
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 44
		l.outline_size = 12
		l.pixel_size = 0.01
		l.position.y = 2.6
		holder.add_child(l)
		_labels.append(l)
		_plants.append(null)
		_shown_state.append("")
	_refresh()

## Redesenha as plantas que mudaram de estado/cultura e os letreiros.
func _refresh() -> void:
	for i in _nodes.size():
		var key := "%s|%s|%d" % [farm.plots[i].crop, farm.state(i), int(farm.progress(i) * 4.0)]
		if key != _shown_state[i]:
			_shown_state[i] = key
			if _plants[i] and is_instance_valid(_plants[i]):
				_plants[i].free()
			_plants[i] = null
			var crop: String = farm.plots[i].crop
			if crop != "":
				var holder := Node3D.new()
				_nodes[i].add_child(holder)
				for k in 4: # 4 plantas por talhão
					var m: Node3D = (load("res://assets/kit/" + PLANT[crop][0] + ".gltf") as PackedScene).instantiate()
					holder.add_child(m)
					KitUtil.fit_height(m, float(PLANT[crop][1]) * lerpf(0.25, 1.0, farm.progress(i)))
					m.position += Vector3(-0.7 + 1.4 * (k % 2), 0.15, -0.7 + 1.4 * (k / 2))
					CelShading.apply(m)
				_plants[i] = holder
		var l := _labels[i]
		match farm.state(i):
			"empty":
				l.text = tr("PLOT_EMPTY")
				l.modulate = Color(1, 1, 1, 0.75)
			"growing":
				l.text = "%s\n%s" % [tr("CROP_" + farm.plots[i].crop.to_upper()), DeliveryHud.format_time(farm.remaining(i))]
				l.modulate = Color.WHITE
			"ready":
				l.text = "%s\n%s" % [tr("CROP_" + farm.plots[i].crop.to_upper()), tr("PLOT_READY")]
				l.modulate = Color("ffc857")

func nearest_plot() -> int:
	if run.in_vehicle():
		return -1
	var d: PlanetData = run.planet.data
	var best := -1
	var best_d := PLOT_RADIUS
	for i in plot_total():
		var p: Vector3 = run.planet.to_global(d.surface_point(d.farm_plots[i]))
		var dist: float = run.player.global_position.distance_to(p)
		if dist < best_d:
			best_d = dist
			best = i
	return best

func plant(i: int, crop: String) -> bool:
	if not farm.plant(i, crop, run.wallet):
		return false
	_refresh()
	run.autosave()
	return true

func harvest(i: int) -> int:
	var crop: String = farm.plots[i].crop
	var n := farm.harvest(i, run.wallet)
	if n > 0:
		run.deliveries.hud.toast(tr("TOAST_HARVEST") % [n, tr("RES_" + str(Farm.CROPS[crop].resource).to_upper())])
		_refresh()
		run.autosave()
	return n

func hint() -> String:
	var i := nearest_plot()
	if i < 0:
		return ""
	match farm.state(i):
		"empty":
			return tr("HINT_PLANT")
		"ready":
			return tr("HINT_HARVEST")
	return tr("HINT_GROWING") % DeliveryHud.format_time(farm.remaining(i))

## Ação ao pé de um talhão. Devolve se tratou.
func act() -> bool:
	var i := nearest_plot()
	if i < 0:
		return false
	match farm.state(i):
		"empty":
			run.outpost.menu_open = true
			menu.open(i)
			run.touch.visible = false
			run.player.controllable = false
		"ready":
			harvest(i)
	return true

func _process(delta: float) -> void:
	if run == null:
		return
	farm.tick(delta)
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		_refresh()
