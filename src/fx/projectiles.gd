class_name Projectiles
extends Node3D
## Projéteis do mech: balas luminosas que voam até ao alvo e só fazem dano quando lhe tocam.
## Seguem um pouco o alvo (a mira é automática, as criaturas mexem-se). Conjunto fixo, sem
## alocações durante o jogo.

signal hit(target: Creature, at: Vector3)

const SPEED := 40.0 # m/s
const LIFE := 1.0 # s (alcance ~40 m)
const HOMING := 6.0 # quanto corrigem o rumo por segundo
const AIM_UP := 0.9 # apontam a esta altura acima dos pés do alvo

var _pool: Array[MeshInstance3D] = []
var _vel: Array[Vector3] = []
var _life: Array[float] = []
var _target: Array = [] # Creature ou null
var _damage: Array[float] = []
var _i := 0

func setup(count: int, color: Color) -> void:
	var cm := CapsuleMesh.new()
	cm.radius = 0.24
	cm.height = 1.6
	cm.radial_segments = 8
	cm.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	cm.material = mat
	for k in count:
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.top_level = true
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_pool.append(mi)
		_vel.append(Vector3.ZERO)
		_life.append(0.0)
		_target.append(null)
		_damage.append(0.0)

static func aim_point(c: Creature) -> Vector3:
	var up := c.global_position - c.planet.global_position if c.planet else Vector3.UP
	return c.global_position + up.normalized() * AIM_UP

## Dispara de `from` para `target` com `damage`.
func fire(from: Vector3, target: Creature, damage: float) -> void:
	if _pool.is_empty() or target == null:
		return
	var k := _i % _pool.size()
	_i += 1
	_pool[k].global_position = from
	_vel[k] = (aim_point(target) - from).normalized() * SPEED
	_life[k] = LIFE
	_target[k] = target
	_damage[k] = damage
	_pool[k].visible = true
	_orient(k)

## Quantos projéteis estão no ar (testes).
func active_count() -> int:
	return _pool.filter(func(m: MeshInstance3D) -> bool: return m.visible).size()

func _physics_process(delta: float) -> void:
	for k in _pool.size():
		if not _pool[k].visible:
			continue
		_life[k] -= delta
		var t = _target[k]
		var alive: bool = t != null and is_instance_valid(t) and not (t as Creature).dead
		if alive:
			var want := (aim_point(t) - _pool[k].global_position).normalized() * SPEED
			_vel[k] = _vel[k].lerp(want, clampf(HOMING * delta, 0.0, 1.0)).normalized() * SPEED
		var from := _pool[k].global_position
		var to := from + _vel[k] * delta
		_pool[k].global_position = to
		_orient(k)
		if alive and _segment_dist(aim_point(t), from, to) <= (t as Creature).hit_radius():
			(t as Creature).take_hit(_damage[k])
			hit.emit(t, to)
			_pool[k].visible = false
			continue
		if _life[k] <= 0.0:
			_pool[k].visible = false

func _orient(k: int) -> void:
	var v := _vel[k]
	if v.length() < 0.01:
		return
	var y := v.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	_pool[k].global_basis = Basis(x, y, x.cross(y))

## Distância de `p` ao segmento a–b (para não "atravessar" alvos a alta velocidade).
static func _segment_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)
