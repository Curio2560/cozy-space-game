class_name DefenseController
extends Node
## Defesa à noite (F4 #38): lança as vagas (regras em NightWaves), cria as criaturas da noite à
## volta do posto, escolhe o alvo de cada uma (edifício mais perto ou o jogador perto) e mostra a
## vaga no HUD. O dano aos edifícios sai pelo sinal `building_hit` (#41).

signal building_hit(slot: int, damage: float)

const SPAWN_ARC_M := 52.0 # nascem a esta distância do posto
const SPREAD := 0.7 # rad: abertura do grupo de cada vaga
const PLAYER_AGGRO_M := 9.0 # o jogador a esta distância passa a ser o alvo
const PLAYER_REACH := 1.9
const ROVER_REACH := 2.6
const BUILDING_REACH := 3.2
const BUILDING_DAMAGE := 6.0
## Famílias que atacam à noite (as bolhas pequenas ficam em casa).
const RAID_FAMILIES := ["big", "flying"]

var run: Node3D
var waves := NightWaves.new()
var raiders: Array[Creature] = []
var label: Label
## Diz se o edifício do slot `i` ainda pode ser atacado ou disparar (desligados não).
var building_alive: Callable = func(i: int) -> bool: return run.outpost.state.is_working(i)
## Contas da noite (#42): dano aos edifícios e quantos ficaram desligados.
var night_damage := 0.0
var night_broken := 0
## Ganho nesta noite (vagas vencidas + bónus): {recurso: n}.
var night_gain := {}
var _rng := RandomNumberGenerator.new()
var beams: Beams
var _turret_cd := {}

func setup(p_run: Node3D, hud_layer: CanvasLayer) -> void:
	run = p_run
	_rng.randomize()
	waves.spawn.connect(_spawn_wave)
	waves.wave_started.connect(func(w: int, n: int) -> void:
		run.deliveries.hud.toast(tr("TOAST_WAVE") % [w, NightWaves.WAVES, n]))
	waves.wave_cleared.connect(_on_wave_cleared)
	beams = Beams.new()
	beams.name = "TurretBeams"
	add_child(beams)
	beams.setup(8, Color("ff5fa2"), 0.09, 0.1)
	label = Label.new()
	label.name = "WaveLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("ff8a8a"))
	label.add_theme_color_override("font_outline_color", CozyTheme.INK)
	label.add_theme_constant_override("outline_size", 7)
	hud_layer.add_child(label)
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.offset_right = -20.0
	label.offset_left = -400.0
	label.offset_top = 76.0 + Minimap.SIZE + 38.0
	label.offset_bottom = label.offset_top + 34.0
	label.visible = false
	waves.changed.connect(_update_label)

func start_night(n: int) -> void:
	clear()
	night_damage = 0.0
	night_broken = 0
	night_gain = {}
	waves.start_night(n)

## Retoma uma noite a meio (save carregado de noite): salta as vagas cujo tempo já passou.
func resume_night(n: int, night_clock: float) -> void:
	start_night(n)
	waves.clock = night_clock
	var past := 0
	for t in NightWaves.WAVE_AT:
		if night_clock >= t:
			past += 1
	waves.wave = maxi(past - 1, 0)
	waves.cleared = waves.wave

## Amanheceu: as criaturas da noite que restam vão-se embora.
func end_night() -> void:
	waves.end_night()
	clear()

## Remove as criaturas da noite (encolhem e desaparecem).
func clear() -> void:
	for c in raiders:
		if is_instance_valid(c) and not c.dead:
			c.dead = true
			var tw := c.create_tween()
			tw.tween_property(c, "scale", Vector3.ONE * 0.01, 0.4)
			tw.tween_callback(c.queue_free)
	raiders.clear()

func _physics_process(delta: float) -> void:
	waves.tick(delta)
	_tick_turrets(delta)

## Torres laser: apontam e disparam na criatura da noite mais perto ao alcance.
func _tick_turrets(delta: float) -> void:
	if raiders.is_empty() or run.outpost == null:
		return
	var st: Outpost = run.outpost.state
	var live := raiders.filter(func(c: Creature) -> bool: return is_instance_valid(c) and not c.dead)
	var pos := live.map(func(c: Creature) -> Vector3: return c.global_position)
	for i in st.turrets():
		if not building_alive.call(i):
			continue
		var head: Node3D = run.outpost.turret_heads.get(i)
		if head == null or not is_instance_valid(head):
			continue
		_turret_cd[i] = float(_turret_cd.get(i, 0.0)) - delta
		var stats := st.turret_stats(i)
		var k := MechGun.nearest(head.global_position, pos, stats.range)
		if k < 0:
			continue
		var c: Creature = live[k]
		aim_head(head, c.global_position)
		if _turret_cd[i] <= 0.0:
			_turret_cd[i] = stats.interval
			var up: Vector3 = (c.global_position - run.planet.global_position).normalized()
			beams.fire(head.global_position, c.global_position + up * 0.9)
			c.take_hit(stats.damage)

## Roda a cabeça da torre (só à volta da vertical) para o canhão (-X do modelo) apontar.
static func aim_head(head: Node3D, at: Vector3) -> void:
	var b := head.global_basis
	var s := b.get_scale()
	var u := b.y.normalized()
	var t := at - head.global_position
	t = t - u * t.dot(u)
	if t.length() < 0.01:
		return
	var x := -t.normalized()
	head.global_basis = Basis(x, u, x.cross(u)).scaled(s)

func _spawn_wave(count: int, hp: float) -> void:
	var d: PlanetData = run.planet.data
	var ids := CreatureCatalog.ids().filter(func(i: String) -> bool: return CreatureCatalog.family(i) in RAID_FAMILIES)
	if ids.is_empty():
		ids = CreatureCatalog.ids()
	var bearing := _rng.randf() * TAU
	var b := SphereMath.basis_from_up(d.outpost_dir)
	for k in count:
		var ang := bearing + _rng.randf_range(-SPREAD, SPREAD)
		var axis := (b.x * cos(ang) + b.z * sin(ang)).cross(d.outpost_dir).normalized()
		var arc := (SPAWN_ARC_M + _rng.randf_range(-6.0, 6.0)) / d.radius
		var dir := d.outpost_dir.rotated(axis, -arc)
		var c := Creature.new()
		c.name = "Raider%d" % _rng.randi()
		run.add_child(c)
		c.setup(ids[_rng.randi() % ids.size()], run.planet, dir, run.biome, _rng.randi())
		c.raider = true
		c.max_health = hp
		c.health = hp
		c.set_personality(Creature.Personality.AGGRESSIVE)
		c.target = run._creature_target
		c.raid_target = _target_for.bind(c)
		c.raid_hit.connect(_on_raid_hit)
		c.died.connect(_on_died)
		c.flock = raiders
		raiders.append(c)

## Alvo de uma criatura da noite: o jogador (ou o rover) se estiver perto; senão o edifício de
## pé mais perto; sem edifícios, o jogador onde estiver.
func _target_for(c: Creature) -> Array:
	var d: PlanetData = run.planet.data
	var who: Node3D = run.carrier_node()
	if run.respawning:
		who = null
	var who_dir: Vector3 = run.planet.to_local(who.global_position).normalized() if who else Vector3.ZERO
	var reach: float = ROVER_REACH if run.in_vehicle() else PLAYER_REACH
	if who and d.arc_m(c.dir, who_dir) < PLAYER_AGGRO_M:
		return [who.global_position, reach, "player"]
	var best := -1
	var best_m := INF
	var slots: Array = run.outpost.state.slots
	for i in mini(slots.size(), run.outpost.slot_total()):
		if slots[i].kind == "" or not building_alive.call(i):
			continue
		var m := d.arc_m(c.dir, d.outpost_slots[i])
		if m < best_m:
			best_m = m
			best = i
	if best >= 0:
		return [run.planet.to_global(d.surface_point(d.outpost_slots[best])), BUILDING_REACH, best]
	if who:
		return [who.global_position, reach, "player"]
	return []

func _on_raid_hit(c: Creature, key: Variant) -> void:
	if key is String and key == "player":
		run._on_creature_attack(c)
	elif key is int:
		night_damage += BUILDING_DAMAGE
		if run.outpost.damage_building(key, BUILDING_DAMAGE):
			night_broken += 1
		building_hit.emit(key, BUILDING_DAMAGE)

## Vaga vencida: paga já (créditos e dados) e soma às contas da noite.
func _on_wave_cleared(w: int) -> void:
	var r := NightWaves.wave_reward(waves.night, w)
	_gain(r)
	run.deliveries.hud.toast(tr("TOAST_WAVE_CLEARED") % [w, r[Wallet.CREDITS], r[Wallet.DATA]])

func _gain(r: Dictionary) -> void:
	for k in r:
		run.wallet.add(k, int(r[k]))
		night_gain[k] = int(night_gain.get(k, 0)) + int(r[k])

## Fecha a noite (ao amanhecer): bónus da noite perfeita e o resumo para o ecrã da manhã.
## {night, cleared, waves, damage, broken, credits, data, perfect}
func finish_night() -> Dictionary:
	var n := waves.night
	if n <= 0:
		return {}
	var perfect := waves.all_cleared() and night_damage <= 0.0
	if perfect:
		_gain(NightWaves.perfect_bonus(n))
	var rep := {"night": n, "cleared": waves.cleared, "waves": NightWaves.WAVES, "damage": night_damage,
		"broken": night_broken, "credits": int(night_gain.get(Wallet.CREDITS, 0)),
		"data": int(night_gain.get(Wallet.DATA, 0)), "perfect": perfect}
	end_night()
	return rep

func _on_died(c: Creature) -> void:
	raiders.erase(c)
	waves.killed()

func _update_label() -> void:
	label.visible = waves.active() and waves.wave > 0
	if label.visible:
		label.text = tr("HUD_WAVE") % [waves.wave, NightWaves.WAVES, waves.alive]
