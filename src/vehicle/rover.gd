class_name Rover
extends RigidBody3D
## Rover arcade para planetas esféricos: corpo rígido com 4 raios de suspensão (molas),
## gravidade para o centro do planeta, aderência lateral, tração e direção arcade,
## e endireita-se sozinho se capotar. Regista embates (para as encomendas frágeis).

signal bumped(strength: float)
signal health_changed(value: float, max_value: float)
signal destroyed

const MODEL := "veiculos/Rover_1"
const LENGTH := 2.8 # m
const MODEL_LENGTH := 5.159168 # comprimento do modelo do kit
const MODEL_WHEEL_Y := 0.526459
const MODEL_WHEEL_BOTTOM := -0.149513
const MODEL_WHEELS := {
	"Wheel_1": Vector3(1.796197, 0, -1.896661), "Wheel_2": Vector3(-1.796197, 0, 1.896661),
	"Wheel_3": Vector3(1.796197, 0, 1.896661), "Wheel_4": Vector3(-1.796197, 0, -1.896661),
}

@export var gravity := 22.0
@export var engine_force := 2600.0
@export var max_speed := 15.0
@export var reverse_factor := 0.5
@export var turn_rate := 2.2 # rad/s em velocidade
@export var spring_k := 4200.0
@export var spring_damp := 260.0 # pouco amortecimento = mais saltitão
@export var rest_length := 0.35
@export var grip := 9.0
@export var air_align := 1.6 # baixo: no ar dá para dar cambalhotas
@export var spin_damp := 0.6 # amortecimento da rotação (baixo = capota mais)
@export var max_health := 100.0
@export var bump_damage := 22.0 # vida perdida por unidade de "força" de embate
@export var bump_cooldown := 0.35
@export var bump_threshold := 28.0 # m/s² acima do esperado conta como embate

var planet_center := Vector3.ZERO
## Quem conduz trata do input; sem condutor o rover trava.
var driven := false
var throttle := 0.0
var steer := 0.0
var wheel_radius: float
var grounded_wheels := 0
var bump_total := 0.0
var health := 100.0
var alive := true
var _bump_cd := 0.0

var _anchors: Array[Vector3] = []
var _wheel_nodes: Array[Node3D] = []
var _wheel_rest_y: Array[float] = []
var _flipped_time := 0.0
var _prev_velocity := Vector3.ZERO
var _spin := 0.0
var _k := 1.0

func _ready() -> void:
	mass = 150.0
	gravity_scale = 0.0
	linear_damp = 0.05
	angular_damp = spin_damp
	health = max_health
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.1, 0)
	can_sleep = false
	_k = LENGTH / MODEL_LENGTH
	wheel_radius = (MODEL_WHEEL_Y - MODEL_WHEEL_BOTTOM) * _k
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var model: Node3D = (load("res://assets/kit/" + MODEL + ".gltf") as PackedScene).instantiate()
	visual.add_child(model)
	model.scale = Vector3.ONE * _k
	model.position.y = -MODEL_WHEEL_Y * _k # rodas centradas em y = 0 local
	CelShading.apply(model)
	for wn: String in MODEL_WHEELS:
		var w := model.get_node_or_null(wn) as Node3D
		var a: Vector3 = MODEL_WHEELS[wn] * _k
		_anchors.append(Vector3(a.x, 0.0, a.z))
		_wheel_nodes.append(w)
		_wheel_rest_y.append(w.position.y if w else 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 0.8, 2.5)
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)

func planet_up() -> Vector3:
	return (global_position - planet_center).normalized()

func forward() -> Vector3:
	return global_basis.z.normalized()

func speed() -> float:
	return linear_velocity.dot(forward())

## Pousa o rover em `pos` (global), alinhado com a superfície, virado para `facing`.
func place_at(pos: Vector3, facing: Vector3) -> void:
	var u := (pos - planet_center).normalized()
	var f := (facing - u * facing.dot(u)).normalized()
	if f.length() < 0.01:
		f = SphereMath.basis_from_up(u).z
	global_transform = Transform3D(Basis(u.cross(f).normalized(), u, f).orthonormalized(), pos)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_prev_velocity = Vector3.ZERO
	_bump_cd = 0.4 # pousar o rover não conta como embate

func _physics_process(delta: float) -> void:
	var u := planet_up()
	var b := global_basis
	var r_up := b.y.normalized()
	var ray_len := rest_length + wheel_radius
	var space := get_world_3d().direct_space_state
	grounded_wheels = 0
	var fwd := forward()
	var right := b.x.normalized()

	apply_central_force(-u * gravity * mass)

	for i in _anchors.size():
		var from := global_transform * _anchors[i]
		var to := from - r_up * ray_len
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		var dist := ray_len
		if not hit.is_empty():
			grounded_wheels += 1
			dist = from.distance_to(hit.position)
			var compression := ray_len - dist
			var offset := from - global_position
			var point_vel := linear_velocity + angular_velocity.cross(offset)
			var spring := spring_k * compression - spring_damp * point_vel.dot(r_up)
			apply_force(r_up * maxf(spring, 0.0), offset)
			# Aderência lateral: anula a velocidade de lado em cada roda.
			var side_v := point_vel.dot(right)
			apply_force(-right * side_v * grip * mass / _anchors.size(), offset)
			if not driven:
				var long_v := point_vel.dot(fwd)
				apply_force(-fwd * long_v * grip * 0.5 * mass / _anchors.size(), offset)
		_update_wheel_visual(i, dist)

	var on_ground := grounded_wheels >= 2
	if on_ground and driven:
		var spd := speed()
		var limit := max_speed if throttle >= 0.0 else max_speed * reverse_factor
		var room := clampf(1.0 - absf(spd) / limit, 0.0, 1.0) if signf(spd) == signf(throttle) else 1.0
		apply_central_force(fwd * throttle * engine_force * room)
		# Direção arcade: velocidade angular à volta do "cima" do rover.
		var speed_k := clampf(spd / 4.0, -1.0, 1.0)
		var target_w := -steer * turn_rate * speed_k
		var w_up := angular_velocity.dot(r_up)
		angular_velocity += r_up * (target_w - w_up) * clampf(10.0 * delta, 0.0, 1.0)
	if not on_ground:
		# No ar: tende a alinhar com o planeta para aterrar de rodas.
		apply_torque(r_up.cross(u) * air_align * mass)

	angular_damp = spin_damp
	_bump_cd = maxf(_bump_cd - delta, 0.0)
	_check_bump(delta, u)
	_check_flip(delta, u)
	_spin += speed() * delta / maxf(wheel_radius, 0.01)

func _update_wheel_visual(i: int, dist: float) -> void:
	var w := _wheel_nodes[i]
	if w == null:
		return
	var drop := (dist - wheel_radius) / _k # em unidades do modelo
	w.position.y = _wheel_rest_y[i] - drop
	w.rotation.x = _spin

func _check_bump(delta: float, u: Vector3) -> void:
	if delta <= 0.0:
		return
	var accel := (linear_velocity - _prev_velocity) / delta + u * gravity
	_prev_velocity = linear_velocity
	var a := accel.length()
	if a > bump_threshold:
		var strength := (a - bump_threshold) / bump_threshold
		bump_total += strength
		bumped.emit(strength)
		if _bump_cd <= 0.0:
			_bump_cd = bump_cooldown
			take_damage(minf(strength * bump_damage, 60.0))

## Tira vida ao rover (embates, ácido, criaturas). A 0 emite `destroyed` (uma vez).
func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		alive = false
		destroyed.emit()

func repair(amount: float) -> void:
	if not alive or health >= max_health:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)

## Destroços: o rover salta pelo ar a rodopiar e fica carbonizado (para se ver a explosão).
func wreck() -> void:
	driven = false
	throttle = 0.0
	steer = 0.0
	_set_charred(true)
	var u := planet_up()
	apply_central_impulse(u * mass * 9.0 + forward() * mass * 1.5)
	apply_torque_impulse((global_basis.x * 1.2 + global_basis.z * 0.6) * mass * 2.5)

## Volta a pôr o rover inteiro (depois de explodir).
func restore() -> void:
	alive = true
	health = max_health
	_bump_cd = 1.0
	visible = true
	freeze = false
	_set_charred(false)
	health_changed.emit(health, max_health)

static var _char_mat: StandardMaterial3D

func is_charred() -> bool:
	return has_meta(&"charred")

func _set_charred(on: bool) -> void:
	if _char_mat == null:
		_char_mat = StandardMaterial3D.new()
		_char_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_char_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_char_mat.albedo_color = Color(0.08, 0.05, 0.06, 0.72)
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _char_mat if on else null
	if on:
		set_meta(&"charred", true)
	elif has_meta(&"charred"):
		remove_meta(&"charred")

func _check_flip(delta: float, u: Vector3) -> void:
	if global_basis.y.normalized().dot(u) < 0.35 and linear_velocity.length() < 4.0:
		_flipped_time += delta
		if _flipped_time > 1.2:
			_flipped_time = 0.0
			place_at(global_position + u * 1.2, forward())
	else:
		_flipped_time = 0.0
