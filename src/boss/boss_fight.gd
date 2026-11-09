class_name BossFight
extends Node
## Luta com o boss (F5 #46/#47). Com os 3 KeyCards, Ação na porta do covil: o ecrã escurece,
## o boss aparece na arena ao lado e o jogador já está no mech, na borda da arena. Durante a
## luta o relógio e as vagas param e não se sai do mech. Mech avariado = derrota (acorda-se no
## posto; os KeyCards ficam; o boss recupera). Boss a 0 = vitória.

signal won
signal lost

enum State { IDLE, INTRO, FIGHT, OUTRO }

const DOOR_RADIUS := 5.0
const HP_BAR_W := 520.0

var run: Node3D
var state := State.IDLE
var boss: Boss
var beaten := false # boss deste planeta já vencido
var summons: Array[Creature] = []
var bar: ProgressBar
var bar_label: Label
var _action := JumpBuffer.new()

func setup(p_run: Node3D, hud_layer: CanvasLayer) -> void:
	run = p_run
	var box := VBoxContainer.new()
	box.name = "BossBar"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -HP_BAR_W * 0.5
	box.offset_right = HP_BAR_W * 0.5
	box.offset_top = 70.0
	bar_label = Label.new()
	bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_label.add_theme_font_size_override("font_size", 24)
	bar_label.add_theme_color_override("font_color", Color("e7c6ff"))
	bar_label.add_theme_color_override("font_outline_color", CozyTheme.INK)
	bar_label.add_theme_constant_override("outline_size", 7)
	box.add_child(bar_label)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(HP_BAR_W, 24)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.1, 0.22, 0.8)
	bg.set_corner_radius_all(8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("b46bff")
	fg.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	box.add_child(bar)
	box.visible = false

func in_fight() -> bool:
	return state != State.IDLE

func door_position() -> Vector3:
	var d: PlanetData = run.planet.data
	return run.planet.to_global(d.surface_point(d.lair_door))

func near_door() -> bool:
	return not run.in_vehicle() and run.player.global_position.distance_to(door_position()) < DOOR_RADIUS

func can_start() -> bool:
	return state == State.IDLE and not beaten and run.deliveries.session.lair_open() and near_door() \
		and not run.morning_open and not run.respawning

func hint() -> String:
	if state != State.IDLE or not near_door() or beaten:
		return ""
	if run.deliveries.session.lair_open():
		return tr("HINT_BOSS_START")
	return tr("HINT_LAIR_LOCKED") % [run.deliveries.session.keycards, DeliverySession.KEYCARDS_PER_PLANET]

## Planeta novo: sem luta, boss por vencer.
func reset() -> void:
	_remove_boss()
	state = State.IDLE
	beaten = false
	bar.get_parent().visible = false

func _physics_process(delta: float) -> void:
	if run == null:
		return
	_action.update(Input.is_action_pressed("action"), delta)
	if _action.consume() and can_start():
		start()
	if state == State.FIGHT and is_instance_valid(boss):
		bar.max_value = boss.max_health
		bar.value = boss.health
		bar_label.text = tr("BOSS_NAME") % boss.phase

## Começa a luta (também pelo DBG, sem verificar KeyCards).
func start() -> void:
	if state != State.IDLE:
		return
	state = State.INTRO
	run.cycle.paused = true
	run.defense.suspend(true)
	run.deliveries.hud.toast(tr("TOAST_BOSS_AWAKE"))
	await run._fade(1.0)
	if not is_inside_tree():
		return
	var d: PlanetData = run.planet.data
	var edge := d.toward_point(d.arena_dir, d.lair_dir, -(d.arena_radius_m - 1.5))
	if run.driving:
		run.exit_rover()
	if not run.piloting:
		run.mech.repair_full()
		run.player.place_at(run.planet.to_global(d.surface_point(edge) + edge * 0.5))
	var to_center: Vector3 = run.planet.global_basis * (d.arena_dir - edge)
	run.mech.place_at(run.planet.to_global(d.surface_point(edge) + edge * 0.3), to_center)
	if not run.piloting:
		run.enter_mech()
	_spawn_boss()
	run._apply_camera(run.CAM_BOSS)
	run.tutorial.visible = false
	bar.get_parent().visible = true
	await run._fade(0.0)
	state = State.FIGHT

func _spawn_boss() -> void:
	_remove_boss()
	boss = Boss.new()
	boss.name = "Boss"
	run.add_child(boss)
	boss.setup_boss(run.biome, run.planet_index, run.planet, run.planet.data.arena_dir)
	boss.raider = true # para a mira do mech e o minimapa
	boss.focus = func() -> Node3D: return run.mech
	boss.target = func() -> Node3D: return run.mech
	boss.slammed.connect(_on_slam)
	boss.summon.connect(_on_summon)
	boss.died.connect(func(_c: Creature) -> void: _win())
	boss.phase_changed.connect(func(p: int) -> void:
		run.deliveries.hud.toast(tr("TOAST_BOSS_PHASE_%d" % p)))

func _remove_boss() -> void:
	if is_instance_valid(boss):
		boss.queue_free()
	boss = null
	for c in summons:
		if is_instance_valid(c):
			c.queue_free()
	summons.clear()

## Um golpe do boss acabou: acerta no mech se estiver dentro do círculo.
func _on_slam(center: Vector3, radius: float, damage: float) -> void:
	if state != State.FIGHT or not run.piloting:
		return
	var md: Vector3 = run.planet.to_local(run.mech.global_position).normalized()
	if BossRules.hits(run.planet.data.arc_m(md, center), radius):
		run.mech.take_damage(damage)

## Fase 2+: criaturas à volta do boss que vão direto ao mech.
func _on_summon(count: int) -> void:
	if state != State.FIGHT or not is_instance_valid(boss):
		return
	var d: PlanetData = run.planet.data
	var b := SphereMath.basis_from_up(boss.dir)
	for k in count:
		var ang := TAU * k / count
		var around := d.toward_point(boss.dir, boss.dir + (b.x * cos(ang) + b.z * sin(ang)) * 0.1, 4.0)
		var c := Creature.new()
		c.name = "BossMinion%d" % k
		run.add_child(c)
		c.setup(CreatureCatalog.ids()[(k * 7 + summons.size()) % CreatureCatalog.ids().size()], run.planet, around, run.biome, randi(), true)
		c.max_health = NightWaves.creature_health(1)
		c.health = c.max_health
		c.target = func() -> Node3D: return run.mech
		c.raid_target = func() -> Array: return [run.mech.global_position, DefenseController.ROVER_REACH, "player"]
		c.raid_hit.connect(func(cr: Creature, _k: Variant) -> void: run._on_creature_attack(cr))
		c.died.connect(func(cr: Creature) -> void: summons.erase(cr))
		summons.append(c)

## O mech avariou durante a luta: derrota.
func on_mech_broken() -> void:
	if state != State.FIGHT:
		return
	state = State.OUTRO
	run.deliveries.hud.toast(tr("TOAST_BOSS_LOST"))
	await run._respawn_at_base()
	_end()
	lost.emit()

func _win() -> void:
	if state != State.FIGHT:
		return
	state = State.OUTRO
	beaten = true
	run.deliveries.hud.toast(tr("TOAST_BOSS_WON"))
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	await run._fade(1.0)
	if run.piloting:
		run.exit_mech()
	run.spawn_near(run.planet.data.outpost_dir, run.planet.data.posts[0], 10.5)
	_end()
	won.emit()
	await run._fade(0.0)

func _end() -> void:
	_remove_boss()
	bar.get_parent().visible = false
	run.tutorial.visible = true
	run.mech.repair_full()
	run._park_mech()
	run.cycle.paused = false
	run.defense.suspend(false)
	state = State.IDLE
	run.autosave()

## Todas as criaturas da luta (mira do mech).
func fighters() -> Array:
	var out: Array = summons.duplicate()
	if is_instance_valid(boss) and not boss.dead:
		out.append(boss)
	return out
