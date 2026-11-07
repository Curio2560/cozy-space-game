class_name O2Bubbles
extends Node3D
## Bolhas de O₂ do planeta: esferas translúcidas a flutuar. Tocar numa repõe O₂; volta a
## aparecer passado um bocado. `collect(local_pos)` devolve o O₂ apanhado nesse frame.

var data: PlanetData
var _nodes: Array[MeshInstance3D] = []
var _cooldown: PackedFloat32Array
var _t := 0.0
static var _mesh: SphereMesh

func setup(d: PlanetData) -> void:
	data = d
	for c in get_children():
		c.free()
	_nodes.clear()
	_cooldown = PackedFloat32Array()
	_cooldown.resize(d.o2_bubbles.size())
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.45
		_mesh.height = 0.9
		_mesh.radial_segments = 12
		_mesh.rings = 6
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.55, 0.9, 1.0, 0.55)
		m.emission_enabled = true
		m.emission = Color(0.35, 0.75, 1.0)
		m.emission_energy_multiplier = 0.6
		m.rim_enabled = true
		m.rim = 0.8
		_mesh.material = m
	for i in d.o2_bubbles.size():
		var mi := MeshInstance3D.new()
		mi.name = "Bubble%d" % i
		mi.mesh = _mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_nodes.append(mi)
		_place(i)

func available(i: int) -> bool:
	return _cooldown[i] <= 0.0

func _place(i: int) -> void:
	var dir: Vector3 = data.o2_bubbles[i]
	var bob := sin(_t * 2.0 + i * 1.7) * 0.15
	_nodes[i].position = data.surface_point(dir) + dir * (1.0 + bob)

func _process(delta: float) -> void:
	_t += delta
	for i in _nodes.size():
		if _cooldown[i] > 0.0:
			_cooldown[i] -= delta
			_nodes[i].visible = _cooldown[i] <= 0.0
		if _nodes[i].visible:
			_place(i)

## O₂ apanhado por quem está em `local_pos` (espaço do planeta).
func collect(local_pos: Vector3) -> float:
	var got := 0.0
	for i in _nodes.size():
		if not available(i):
			continue
		if _nodes[i].position.distance_to(local_pos) < AcidHazard.BUBBLE_RADIUS_M:
			_cooldown[i] = AcidHazard.BUBBLE_RESPAWN_S
			_nodes[i].visible = false
			got += AcidHazard.BUBBLE_O2
	return got
