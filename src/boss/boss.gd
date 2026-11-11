class_name Boss
extends Creature
## Boss do planeta (F5 #47): um monstro grande do pack em ponto grande. Anda até ao alvo e
## golpeia o chão com aviso (círculo vermelho). Fase 2 chama criaturas; fase 3 fica mais
## rápido e às vezes faz um ataque em área à volta. Regras em BossRules.

signal phase_changed(phase: int)
signal summon(count: int)
## Um golpe acabou: `center` (direção no planeta), `radius` (m), `damage`.
signal slammed(center: Vector3, radius: float, damage: float)

var phase := 1
## Tom próprio (materiais só do boss, com o contorno roxo a brilhar).
const BOSS_TINT := Color(0.97, 0.93, 1.0)
var focus: Callable # devolve o Node3D a atacar (o mech)
var _attack_t := 2.0
var _summon_t := BossRules.SUMMON_EVERY
var _windup := 0.0
var _slams := 0
var _pending := {} # golpe em preparação: {center, radius, damage}
var _marker: MeshInstance3D

func setup_boss(biome: String, planet_index: int, p_planet: Planet, at: Vector3) -> void:
	setup(BossRules.model_for(biome, planet_index), p_planet, at, biome, 7 + planet_index, false, BOSS_TINT)
	model.scale *= BossRules.SCALE
	CelShading.glow_outline(model, Color(0.75, 0.35, 1.0, 0.85), 0.09)
	max_health = BossRules.health(planet_index)
	health = max_health
	_marker = _make_marker()
	add_child(_marker)

func hit_radius() -> float:
	return 3.2

## Fração de vida (0..1).
func health_frac() -> float:
	return health / max_health if max_health > 0.0 else 0.0

func take_hit(dmg: float) -> void:
	super.take_hit(dmg)
	if dead:
		_marker.visible = false
		return
	var p := BossRules.phase(health_frac())
	if p != phase:
		phase = p
		phase_changed.emit(p)

func _physics_process(delta: float) -> void:
	if planet == null or dead or not focus.is_valid():
		return
	var t: Node3D = focus.call()
	if t == null:
		return
	var to_t := planet.to_local(t.global_position).normalized()
	var dist := planet.data.arc_m(dir, to_t)
	if phase >= 2:
		_summon_t -= delta
		if _summon_t <= 0.0:
			_summon_t = BossRules.SUMMON_EVERY
			summon.emit(BossRules.SUMMON_COUNT)
	if _windup > 0.0:
		_windup -= delta
		_steer_towards(to_t, delta, 4.0)
		_place_marker()
		if _windup <= 0.0:
			_finish_attack()
		_place()
		return
	_attack_t -= delta
	_steer_towards(to_t, delta, 5.0)
	if _attack_t <= 0.0:
		_start_attack(to_t)
		_place()
		return
	if dist > BossRules.KEEP_DISTANCE:
		mode = Mode.CHASE
		_move(delta, BossRules.SPEED[phase - 1])
	else:
		mode = Mode.WATCH
		_place()
	_update_anim()

func _start_attack(target_dir: Vector3) -> void:
	_slams += 1
	if phase == 3 and _slams % BossRules.AREA_EVERY == 0:
		_pending = {"center": dir, "radius": BossRules.AREA_RADIUS, "damage": BossRules.AREA_DAMAGE}
		_windup = BossRules.AREA_WINDUP
	else:
		_pending = {"center": target_dir, "radius": BossRules.SLAM_RADIUS, "damage": BossRules.SLAM_DAMAGE}
		_windup = BossRules.SLAM_WINDUP[phase - 1]
	_marker.visible = true
	_place_marker()
	_play("attack", true)

func _finish_attack() -> void:
	_marker.visible = false
	_attack_t = BossRules.SLAM_COOLDOWN[phase - 1]
	slammed.emit(_pending.center, _pending.radius, _pending.damage)
	_pending = {}

## Golpe a preparar (para os testes e o HUD): {} se nenhum.
func pending_attack() -> Dictionary:
	return _pending

func _make_marker() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.08
	cm.radial_segments = 32
	cm.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.45)
	mat.no_depth_test = false
	cm.material = mat
	mi.mesh = cm
	mi.top_level = true
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Círculo no chão onde o golpe vai cair; pulsa mais depressa perto do fim.
func _place_marker() -> void:
	if _pending.is_empty():
		return
	var c: Vector3 = _pending.center
	var r: float = _pending.radius
	var b := planet.global_basis * SphereMath.basis_from_up(c)
	var pulse := 1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.03)
	_marker.global_transform = Transform3D(b.scaled(Vector3(r * pulse, 1.0, r * pulse)), planet.to_global(planet.data.surface_point(c) + c * 0.12))
