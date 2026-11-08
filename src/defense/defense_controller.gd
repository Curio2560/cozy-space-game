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
## Diz se o edifício do slot `i` ainda pode ser atacado (o #41 desliga os destruídos).
var building_alive: Callable = func(_i: int) -> bool: return true
var _rng := RandomNumberGenerator.new()

func setup(p_run: Node3D, hud_layer: CanvasLayer) -> void:
	run = p_run
	_rng.randomize()
	waves.spawn.connect(_spawn_wave)
	waves.wave_started.connect(func(w: int, n: int) -> void:
		run.deliveries.hud.toast(tr("TOAST_WAVE") % [w, NightWaves.WAVES, n]))
	waves.wave_cleared.connect(func(w: int) -> void:
		run.deliveries.hud.toast(tr("TOAST_WAVE_CLEARED") % w))
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
	var reach: float = ROVER_REACH if run.driving else PLAYER_REACH
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
		building_hit.emit(key, BUILDING_DAMAGE)

func _on_died(c: Creature) -> void:
	raiders.erase(c)
	waves.killed()

func _update_label() -> void:
	label.visible = waves.active() and waves.wave > 0
	if label.visible:
		label.text = tr("HUD_WAVE") % [waves.wave, NightWaves.WAVES, waves.alive]
