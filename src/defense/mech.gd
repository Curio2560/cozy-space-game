class_name Mech
extends CharacterBody3D
## Mech do tripulante ativo (F4 #39). Fica estacionado na base; à noite entra-se com o botão do
## veículo. Joystick para andar (relativo à câmara), mira automática na criatura mais perto,
## DISPARAR (o botão de saltar) com aquecimento (MechGun). Tem vida: a 0 desliga-se e o
## jogador sai; amanhã está reparado.

signal health_changed(value: float, max_value: float)
signal broken

const MODELS := {
	"FinnTheFrog": "mechs/Mech_FinnTheFrog",
	"BarbaraTheBee": "mechs/Mech_BarbaraTheBee",
	"FernandoTheFlamingo": "mechs/Mech_FernandoTheFlamingo",
	"RaeTheRedPanda": "mechs/Mech_RaeTheRedPanda",
}
const HEIGHT := 3.4
const MAX_HEALTH := 160.0
const MUZZLE := Vector3(0.0, 2.3, 1.0) # no espaço do modelo, mais ou menos os canhões
## Velocidade (m/s) a que os pés da animação Walk acompanham o chão, com HEIGHT = 3.4 m
## (medido: os pés recuam ~3,8 m em meio ciclo de 0,83 s). A Run não serve: é para ~14 m/s e
## levanta os pés 2 m (os pés escorregavam e o mech parecia patinar).
const WALK_ANIM_SPEED := 9.2

@export var walk_speed := 5.2
@export var accel := 22.0
@export var gravity := 22.0
var planet_center := Vector3.ZERO
var view: Node3D
var visual: Node3D
var facing := Vector3.FORWARD
var crew := ""
var piloted := false
var health := MAX_HEALTH
## Pesquisa (#51): vida máxima e dano dos tiros.
var max_health := MAX_HEALTH
var damage_factor := 1.0
var gun := MechGun.new()
## Devolve as criaturas que se podem atingir (Array de Creature).
var targets: Callable
var aim: Creature

var _model: Node3D
var _anim: AnimationPlayer
var _anim_name := ""
var beams: Beams
var _shot_i := 0
var _shoot_t := 0.0

func _ready() -> void:
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.5
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.9
	cap.height = 3.0
	shape.shape = cap
	shape.position.y = 1.5
	add_child(shape)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	beams = Beams.new()
	beams.name = "Beams"
	add_child(beams)
	beams.setup(4, Color("ffe27a"))

func set_crew(member: String) -> void:
	if member == crew or not MODELS.has(member):
		return
	crew = member
	if _model:
		_model.free()
	_anim_name = ""
	_model = (load("res://assets/kit/" + MODELS[member] + ".gltf") as PackedScene).instantiate()
	visual.add_child(_model)
	KitUtil.fit_height(_model, HEIGHT)
	CelShading.apply(_model)
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	_anim = aps[0] if not aps.is_empty() else null
	for a in ["Idle", "Walk", "Run"]:
		if _anim and _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")

func up() -> Vector3:
	return (global_position - planet_center).normalized()

func place_at(pos: Vector3, p_facing := Vector3.ZERO) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_align(up())
	var u := up()
	if p_facing != Vector3.ZERO:
		facing = (p_facing - u * p_facing.dot(u)).normalized()
	_turn_visual()

func alive() -> bool:
	return health > 0.0

## DBG: invencível.
var invincible := false

func take_damage(dmg: float) -> void:
	if not alive() or invincible:
		return
	health = maxf(health - dmg, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_play("Death", 0.1)
		broken.emit()
	else:
		_play("HitRecieve_1", 0.05)

func repair_full() -> void:
	health = max_health
	gun = MechGun.new()
	health_changed.emit(health, max_health)
	_anim_name = ""
	_play("Idle")

## A criatura viva mais perto ao alcance da arma (ou null).
func find_target() -> Creature:
	if not targets.is_valid():
		return null
	var list: Array = targets.call().filter(func(c: Creature) -> bool: return is_instance_valid(c) and not c.dead)
	var i := MechGun.nearest(global_position, list.map(func(c: Creature) -> Vector3: return c.global_position))
	return list[i] if i >= 0 else null

func _physics_process(delta: float) -> void:
	var u := up()
	up_direction = u
	_align(u)
	var input := InputHub.move_vector() if piloted and alive() else Vector2.ZERO
	var wish := _move_direction(input, u)
	var vert := u * velocity.dot(u)
	var hor := velocity - vert
	hor = hor.move_toward(wish * walk_speed, accel * delta)
	vert -= u * gravity * delta
	velocity = hor + vert
	move_and_slide()
	# Mira: vira-se para o alvo; sem alvo, para onde anda.
	aim = find_target() if piloted and alive() else null
	var want := wish
	if aim:
		var to := aim.global_position - global_position
		want = (to - u * to.dot(u)).normalized()
	if want.length() > 0.1:
		facing = facing.slerp(want.normalized(), clampf(10.0 * delta, 0.0, 1.0)).normalized()
	facing = (facing - u * facing.dot(u)).normalized()
	_turn_visual()
	var trigger := piloted and alive() and Input.is_action_pressed("jump")
	var shots := gun.tick(delta, trigger, aim != null)
	for i in shots:
		_fire_at(aim)
	_shoot_t = maxf(_shoot_t - delta, 0.0)
	if alive():
		_update_anim(hor.length())

func _fire_at(c: Creature) -> void:
	if c == null:
		return
	c.take_hit(MechGun.DAMAGE * damage_factor)
	Sound.play("mech_shot", -6.0)
	_shoot_t = 0.25
	_shot_i += 1
	var from := visual.global_transform * (MUZZLE + Vector3((0.6 if _shot_i % 2 == 0 else -0.6), 0, 0))
	beams.fire(from, c.global_position + up() * 0.9)

func _turn_visual() -> void:
	var local := global_basis.inverse() * facing
	visual.rotation.y = atan2(local.x, local.z)

func _move_direction(input: Vector2, u: Vector3) -> Vector3:
	if input.length() < 0.01:
		return Vector3.ZERO
	var ref := view.global_basis if view else global_basis
	var fwd := -ref.z
	fwd = fwd - u * fwd.dot(u)
	if fwd.length() < 0.01:
		fwd = ref.y - u * ref.y.dot(u)
	fwd = fwd.normalized()
	var right := fwd.cross(u).normalized()
	return (right * input.x + fwd * input.y).limit_length(1.0)

func _align(u: Vector3) -> void:
	var cur := global_basis.y.normalized()
	if cur.dot(u) > 0.99999:
		return
	global_basis = Basis(Quaternion(cur, u) * global_basis.get_rotation_quaternion()).orthonormalized()

func _update_anim(speed: float) -> void:
	if _anim_name.begins_with("HitRecieve") and _anim and _anim.is_playing():
		return
	if _shoot_t > 0.0 and speed < 0.6:
		_play("Shoot_Small", 0.08)
	elif speed > 0.4:
		_play("Walk")
		_anim.speed_scale = clampf(speed / WALK_ANIM_SPEED, 0.25, 1.5)
	else:
		_play("Idle")
	if _anim and _anim_name != "Walk":
		_anim.speed_scale = 1.0

func _play(a: String, blend := 0.15) -> void:
	if _anim == null or a == _anim_name or not _anim.has_animation(a):
		return
	_anim_name = a
	_anim.play(a, blend)
