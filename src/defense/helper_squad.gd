class_name HelperSquad
extends Node
## Mechs ajudantes (F6 #59). Desbloqueados pela pesquisa "helpers" e construídos no terminal
## (peças + créditos), até MAX. Vão na nave de planeta em planeta.
## De dia: colhem os talhões prontos e regam os que crescem. À noite: patrulham à volta do
## posto e disparam projéteis nas criaturas da noite perto.

const MAX := 3
const COST := {Wallet.PARTS: 5, Wallet.CREDITS: 200}
const SPEED := 3.6
const HEIGHT := 1.7
const REACH_M := 1.6
const WATER_TIME := 3.0 # s parado ao pé do talhão a regar
const WATER_BONUS := 30.0 # s de crescimento que a rega dá
const WATER_COOLDOWN := 60.0 # s até o mesmo talhão poder ser regado outra vez
const PATROL_M := 13.0
const SHOOT_RANGE := 16.0
const SHOOT_INTERVAL := 0.5
const DAMAGE := 3.0
const MODELS := ["RaeTheRedPanda", "BarbaraTheBee", "FernandoTheFlamingo", "FinnTheFrog"]

var run: Node3D
var count := 0
var helpers: Array[Dictionary] = [] # {node, dir, heading, task, plot, wait, cd, anim, ap}
var projectiles: Projectiles
var _watered := {} # talhão -> tempo restante de espera

func setup(p_run: Node3D) -> void:
	run = p_run
	projectiles = Projectiles.new()
	projectiles.name = "HelperShots"
	add_child(projectiles)
	projectiles.setup(8, Color("8fe3ff"))

func can_build() -> bool:
	return run.research.helpers_unlocked() and count < MAX and run.wallet.can_afford(COST)

## Constrói um ajudante (paga e põe-no na base).
func build() -> bool:
	if not run.research.helpers_unlocked() or count >= MAX or not run.wallet.spend(COST):
		return false
	count += 1
	_spawn(count - 1)
	return true

## Planeta novo (ou save carregado): recria os ajudantes junto à base.
func respawn() -> void:
	for h in helpers:
		if is_instance_valid(h.node):
			h.node.queue_free()
	helpers.clear()
	_watered.clear()
	for i in count:
		_spawn(i)

func _spawn(i: int) -> void:
	var d: PlanetData = run.planet.data
	var b := SphereMath.basis_from_up(d.outpost_dir)
	var ang := TAU * (i + 0.5) / MAX
	var dir := d.toward_point(d.outpost_dir, d.outpost_dir + (b.x * cos(ang) + b.z * sin(ang)) * 0.1, 9.0)
	var node := Node3D.new()
	node.name = "Helper%d" % i
	run.add_child(node)
	var m: Node3D = (load("res://assets/kit/mechs/Mech_" + MODELS[i % MODELS.size()] + ".gltf") as PackedScene).instantiate()
	node.add_child(m)
	KitUtil.fit_height(m, HEIGHT)
	CelShading.apply(m)
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] if not aps.is_empty() else null
	for a in ["Idle", "Walk"]:
		if ap and ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	helpers.append({"node": node, "dir": dir, "heading": b.z, "task": "", "plot": -1, "wait": 0.0, "cd": 0.0, "anim": "", "ap": ap})
	_place(helpers[-1])

func _physics_process(delta: float) -> void:
	if run == null or run.planet == null or run.planet.data == null:
		return
	for k in _watered.keys():
		_watered[k] = float(_watered[k]) - delta
		if _watered[k] <= 0.0:
			_watered.erase(k)
	var night: bool = run.cycle.is_night()
	for i in helpers.size():
		var h: Dictionary = helpers[i]
		if not is_instance_valid(h.node):
			continue
		if night:
			_night(h, i, delta)
		else:
			_day(h, delta)

## De dia: colher o que estiver pronto; senão regar o que cresce (com espera por talhão).
func _day(h: Dictionary, delta: float) -> void:
	var d: PlanetData = run.planet.data
	var farm: Farm = run.farm.farm
	if h.task == "" or h.task == "patrol":
		h.task = "home"
		h.plot = -1
		for i in run.farm.plot_total():
			if farm.state(i) == "ready" and not _claimed(i):
				h.task = "harvest"
				h.plot = i
				break
		if h.task == "home":
			for i in run.farm.plot_total():
				if farm.state(i) == "growing" and not _watered.has(i) and not _claimed(i):
					h.task = "water"
					h.plot = i
					break
	var goal: Vector3 = d.farm_plots[h.plot] if h.plot >= 0 else d.toward_point(d.outpost_dir, h.dir, 9.0)
	if _walk(h, goal, delta):
		match h.task:
			"harvest":
				if farm.state(h.plot) == "ready":
					run.farm.harvest(h.plot)
				h.task = ""
			"water":
				h.wait += delta
				if h.wait >= WATER_TIME:
					farm.water(h.plot, WATER_BONUS)
					_watered[h.plot] = WATER_COOLDOWN
					h.wait = 0.0
					h.task = ""
			_:
				h.task = ""

func _claimed(plot: int) -> bool:
	return helpers.any(func(o: Dictionary) -> bool: return o.plot == plot and o.task in ["harvest", "water"])

## À noite: anda no seu ponto à volta do posto e dispara nas criaturas da noite perto.
func _night(h: Dictionary, i: int, delta: float) -> void:
	var d: PlanetData = run.planet.data
	h.task = "patrol"
	h.plot = -1
	var b := SphereMath.basis_from_up(d.outpost_dir)
	var ang := TAU * (i + 0.5) / MAX + Time.get_ticks_msec() * 0.00008
	var goal := d.toward_point(d.outpost_dir, d.outpost_dir + (b.x * cos(ang) + b.z * sin(ang)) * 0.1, PATROL_M)
	_walk(h, goal, delta)
	h.cd = maxf(float(h.cd) - delta, 0.0)
	if h.cd > 0.0:
		return
	var node: Node3D = h.node
	var live: Array = run.defense.raiders.filter(func(c: Creature) -> bool: return is_instance_valid(c) and not c.dead)
	var k := MechGun.nearest(node.global_position, live.map(func(c: Creature) -> Vector3: return c.global_position), SHOOT_RANGE)
	if k < 0:
		return
	h.cd = SHOOT_INTERVAL
	var up: Vector3 = (node.global_position - run.planet.global_position).normalized()
	projectiles.fire(node.global_position + up * 1.2, live[k], DAMAGE)
	_play(h, "Shoot_Small")

## Anda para `goal` (direção no planeta). Devolve true quando chegou.
func _walk(h: Dictionary, goal: Vector3, delta: float) -> bool:
	var d: PlanetData = run.planet.data
	var dir: Vector3 = h.dir
	var dist := d.arc_m(dir, goal)
	if dist <= REACH_M:
		_play(h, "Idle")
		return true
	var want := goal - dir * goal.dot(dir)
	if want.length() > 0.0001:
		h.heading = want.normalized()
	h.dir = (dir + h.heading * (minf(SPEED * delta, dist) / d.radius)).normalized()
	_place(h)
	_play(h, "Walk")
	return false

func _place(h: Dictionary) -> void:
	var d: PlanetData = run.planet.data
	var y: Vector3 = h.dir
	var z: Vector3 = (h.heading - y * h.heading.dot(y)).normalized()
	if z.length() < 0.5:
		z = SphereMath.basis_from_up(y).z
	var x := y.cross(z).normalized()
	(h.node as Node3D).global_transform = run.planet.global_transform * Transform3D(Basis(x, y, x.cross(y)), d.surface_point(y))

func _play(h: Dictionary, a: String) -> void:
	var ap: AnimationPlayer = h.ap
	if ap == null or h.anim == a or not ap.has_animation(a):
		return
	if h.anim == "Shoot_Small" and ap.is_playing() and a != "Shoot_Small":
		return
	h.anim = a
	ap.play(a, 0.15)

func to_dict() -> Dictionary:
	return {"count": count}

func from_dict(dd: Dictionary) -> void:
	count = clampi(int(dd.get("count", 0)), 0, MAX)
