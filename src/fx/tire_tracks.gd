class_name TireTracks
extends MultiMeshInstance3D
## Rastos das rodas: cada roda que toca no chão deixa uma marca a cada SPACING metros; as marcas
## esbatem-se e desaparecem ao fim de LIFETIME segundos (grupo reciclado de MAX marcas).

const MAX := 1400
const LIFETIME := 25.0
const SPACING := 0.32
const SIZE := Vector2(0.26, 0.6) # mais comprida que o espaçamento: rasto contínuo
const ALPHA := 0.38
const LIFT := 0.04

var _next := 0
var _born := PackedFloat32Array()
var _time := 0.0
var _last := {} # roda -> última posição marcada
var _fade_timer := 0.0
var placed := 0 # marcas feitas (para testes e DBG)

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = SIZE
	quad.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = MAX
	var hidden := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	for i in MAX:
		mm.set_instance_transform(i, hidden)
		mm.set_instance_color(i, Color(0, 0, 0, 0))
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3.ONE * -300.0, Vector3.ONE * 600.0)
	_born.resize(MAX)
	_born.fill(-1000.0)

## Marca da roda `wheel` no ponto `pos` (global), com `up` = normal do chão e `forward` = sentido.
func mark(wheel: int, pos: Vector3, up: Vector3, forward: Vector3) -> void:
	if _last.has(wheel) and (_last[wheel] as Vector3).distance_to(pos) < SPACING:
		return
	_last[wheel] = pos
	var u := up.normalized()
	var f := (forward - u * forward.dot(u))
	if f.length() < 0.001:
		return
	var z := f.normalized()
	var x := u.cross(z).normalized()
	multimesh.set_instance_transform(_next, Transform3D(Basis(x, u, x.cross(u)), to_local(pos + u * LIFT)))
	multimesh.set_instance_color(_next, Color(0.1, 0.07, 0.05, ALPHA))
	_born[_next] = _time
	_next = (_next + 1) % MAX
	placed += 1

## A roda saiu do chão: o próximo rasto começa de novo.
func lift(wheel: int) -> void:
	_last.erase(wheel)

func _process(delta: float) -> void:
	_time += delta
	_fade_timer -= delta
	if _fade_timer > 0.0:
		return
	_fade_timer = 0.25
	for i in MAX:
		var age := _time - _born[i]
		if age < 0.0 or age > LIFETIME + 1.0:
			continue
		multimesh.set_instance_color(i, Color(0.1, 0.07, 0.05, ALPHA * clampf(1.0 - age / LIFETIME, 0.0, 1.0)))

## Transparência atual da marca `i` (calculada pela idade, igual à que se pinta).
func alpha_of(i: int) -> float:
	var age := _time - _born[i]
	if age < 0.0 or _born[i] < -999.0:
		return 0.0
	return ALPHA * clampf(1.0 - age / LIFETIME, 0.0, 1.0)
