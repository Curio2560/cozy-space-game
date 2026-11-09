class_name Beams
extends Node3D
## Raios curtos (tiros do mech, lasers das torres): um conjunto fixo de cilindros esticados
## entre dois pontos que se mostram por um instante. Sem alocações durante o jogo.

var color := Color("ffe27a")
var radius := 0.06
var life := 0.07
var _pool: Array[MeshInstance3D] = []
var _t: Array[float] = []
var _i := 0

func setup(count: int, p_color: Color, p_radius := 0.06, p_life := 0.07) -> void:
	color = p_color
	radius = p_radius
	life = p_life
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
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
		_t.append(0.0)

func fire(from: Vector3, to: Vector3) -> void:
	if _pool.is_empty():
		return
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var k := _i % _pool.size()
	_i += 1
	var y := (to - from) / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	_pool[k].global_transform = Transform3D(Basis(x, y * length, x.cross(y)), (from + to) * 0.5)
	_pool[k].visible = true
	_t[k] = life

## Quantos raios estão visíveis agora (testes).
func visible_count() -> int:
	return _pool.filter(func(m: MeshInstance3D) -> bool: return m.visible).size()

func _process(delta: float) -> void:
	for k in _pool.size():
		if _pool[k].visible:
			_t[k] -= delta
			_pool[k].visible = _t[k] > 0.0
