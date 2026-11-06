class_name PlanetCamera
extends Camera3D
## Câmara em terceira pessoa para planetas pequenos. Mantém um referencial cujo "cima" é a
## normal do planeta no alvo, transportado sem rodar (não ganha yaw ao andar à volta da
## esfera). Arrastar roda-a; sem input volta sozinha para trás do alvo. Evita obstáculos.

const LOOK_SENS := 0.006

@export var distance := 6.5
@export var pitch := -0.42 # radianos; negativo = câmara acima do alvo
@export var min_pitch := -1.25
@export var max_pitch := -0.05
@export var focus_height := 1.2
@export var follow_sharpness := 10.0
@export var auto_return_delay := 1.6
@export var auto_return_speed := 2.2

var target: Node3D
var planet_center := Vector3.ZERO
## Direção para onde o alvo está virado (para a volta automática); opcional.
var target_facing: Callable

var _frame := Basis.IDENTITY # y = cima do planeta no alvo; -z = "em frente" da câmara
var _idle := 0.0
var _exclude: Array[RID] = []

func set_target(t: Node3D, facing_dir: Vector3) -> void:
	target = t
	var u := _up()
	var f := (facing_dir - u * facing_dir.dot(u)).normalized()
	if f.length() < 0.01:
		f = SphereMath.basis_from_up(u).z * -1.0
	_frame = Basis(f.cross(u).normalized(), u, -f).orthonormalized()
	_exclude.clear()
	if t is CollisionObject3D:
		_exclude.append((t as CollisionObject3D).get_rid())
	global_position = _desired_position()
	look_at(_focus(), u)

func add_exclude(rid: RID) -> void:
	_exclude.append(rid)

func _up() -> Vector3:
	return (target.global_position - planet_center).normalized() if target else Vector3.UP

func _focus() -> Vector3:
	return target.global_position + _up() * focus_height

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var u := _up()
	# Transporte paralelo: roda o referencial o mínimo para o novo "cima".
	var q := Quaternion(_frame.y.normalized(), u)
	_frame = (Basis(q) * _frame).orthonormalized()

	var look := InputHub.consume_look(delta)
	if look.length() > 0.0:
		_idle = 0.0
		_frame = (Basis(u, -look.x * LOOK_SENS) * _frame).orthonormalized()
		pitch = clampf(pitch - look.y * LOOK_SENS, min_pitch, max_pitch)
	else:
		_idle += delta
		if _idle > auto_return_delay and target_facing.is_valid():
			_return_behind(u, target_facing.call(), delta)

	var desired := _desired_position()
	desired = _avoid_obstacles(_focus(), desired)
	global_position = global_position.lerp(desired, clampf(follow_sharpness * delta, 0.0, 1.0))
	look_at(_focus(), u)

func _desired_position() -> Vector3:
	var offset := _frame * (Basis(Vector3.RIGHT, pitch) * Vector3(0, 0, distance))
	return _focus() + offset

func _return_behind(u: Vector3, facing: Vector3, delta: float) -> void:
	var f := facing - u * facing.dot(u)
	if f.length() < 0.01:
		return
	var cam_fwd := -_frame.z
	var ang := cam_fwd.signed_angle_to(f.normalized(), u)
	var step := clampf(ang, -auto_return_speed * delta, auto_return_speed * delta)
	_frame = (Basis(u, step) * _frame).orthonormalized()

func _avoid_obstacles(from: Vector3, to: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return to
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = _exclude
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return to
	return (hit.position as Vector3) + (from - to).normalized() * 0.3
