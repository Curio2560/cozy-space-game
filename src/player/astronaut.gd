class_name Astronaut
extends CharacterBody3D
## Astronauta que anda e salta à volta de um planeta, com a gravidade para o centro.
## O movimento é relativo à câmara e projetado no plano tangente à superfície.

const CREW_MODELS := {
	"FinnTheFrog": "personagens/Astronaut_FinnTheFrog",
	"BarbaraTheBee": "personagens/Astronaut_BarbaraTheBee",
	"FernandoTheFlamingo": "personagens/Astronaut_FernandoTheFlamingo",
	"RaeTheRedPanda": "personagens/Astronaut_RaeTheRedPanda",
}
const HEIGHT := 1.7

@export var walk_speed := 6.5
@export var accel := 35.0
@export var air_accel := 12.0
@export var jump_velocity := 8.5
@export var gravity := 22.0
@export var crew := "FinnTheFrog"
## Vantagens do tripulante (Crew): multiplicam a velocidade a pé e o salto.
var walk_factor := 1.0
var jump_factor := 1.0

## Centro do planeta em coordenadas globais.
var planet_center := Vector3.ZERO
## Referência para o movimento relativo (normalmente a câmara). Sem ela usa a própria orientação.
var view: Node3D
var visual: Node3D
## Direção em que o modelo está virado (global, tangente à superfície).
var facing := Vector3.FORWARD
## Quando falso o astronauta ignora o input (p. ex. dentro do rover).
var controllable := true
## Empurrão (criaturas): soma-se à velocidade e desaparece em menos de um segundo.
var push := Vector3.ZERO

var _anim: AnimationPlayer
## A levar uma caixa nas mãos (a pé): braços à frente e a caixa ao peito.
var carrying := false
var _arms: CarryArms
## Caixa nas mãos: nó filho do visual (segue para onde o astronauta está virado).
var hand_crate: Node3D
const HAND_CRATE_POS := Vector3(0.0, 0.86, 0.5)
var _was_on_floor := true
var _land_t := 0.0
var _jump := JumpBuffer.new()
var _anim_name := ""
## Desmaiado: sem input e sem trocar de animação (fica caído).
var downed := false

func _ready() -> void:
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.4
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	shape.shape = cap
	shape.position.y = 0.8
	add_child(shape)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_model()
	hand_crate = Node3D.new()
	hand_crate.name = "HandCrate"
	hand_crate.position = HAND_CRATE_POS
	hand_crate.visible = false
	visual.add_child(hand_crate)
	var crate: Node3D = (load("res://assets/kit/pickups/Pickup_Crate.gltf") as PackedScene).instantiate()
	hand_crate.add_child(crate)
	KitUtil.fit_height(crate, 0.5)
	CelShading.apply(crate)

var _model: Node3D

## (Re)cria o modelo do tripulante `crew` (cel-shading, animações, braços para a caixa).
func _build_model() -> void:
	if _model:
		_model.free()
	_anim_name = ""
	var model: Node3D = (load("res://assets/kit/" + CREW_MODELS[crew] + ".gltf") as PackedScene).instantiate()
	visual.add_child(model)
	KitUtil.fit_height(model, HEIGHT)
	for n in model.find_children("Pistol*", "MeshInstance3D", true, false):
		(n as Node3D).visible = false # jogo cozy: sem arma
	CelShading.apply(model)
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	_anim = aps[0] if not aps.is_empty() else null
	for a in ["Idle", "Run", "Walk", "Jump_Idle"]:
		if _anim and _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		_arms = CarryArms.new()
		_arms.name = "CarryArms"
		_arms.influence = 0.0
		sks[0].add_child(_arms)
	_model = model

## Troca de tripulante: muda o modelo (a caixa nas mãos e o resto mantêm-se).
func set_crew(member: String) -> void:
	if member == crew or not CREW_MODELS.has(member):
		return
	crew = member
	if visual:
		_build_model()

func up() -> Vector3:
	return (global_position - planet_center).normalized()

## Coloca o astronauta em `pos` (global), alinhado com a superfície e parado.
func place_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_align(up(), 1.0)
	facing = -global_basis.z

func _physics_process(delta: float) -> void:
	var u := up()
	up_direction = u
	_align(u, 1.0)

	var input := InputHub.move_vector() if controllable else Vector2.ZERO
	var wish := move_direction(input, u)
	var vert := u * velocity.dot(u)
	var hor := velocity - vert
	hor = hor.move_toward(wish * walk_speed * walk_factor, (accel if is_on_floor() else air_accel) * delta)

	_jump.update(controllable and Input.is_action_pressed("jump"), delta)
	if is_on_floor() and _jump.consume():
		vert = u * jump_velocity * jump_factor
		_jumped = true
	else:
		vert -= u * gravity * delta
	# O empurrão entra só no movimento deste passo (não fica guardado na velocidade, senão
	# acumulava-se de frame para frame e atirava o astronauta pelo ar).
	velocity = hor + vert + push
	move_and_slide()
	velocity -= push
	push = push.move_toward(Vector3.ZERO, 14.0 * delta)

	if wish.length() > 0.1:
		facing = facing.slerp(wish.normalized(), clampf(14.0 * delta, 0.0, 1.0)).normalized()
	facing = (facing - u * facing.dot(u)).normalized()
	var local := global_basis.inverse() * facing
	visual.rotation.y = atan2(local.x, local.z)
	if not downed:
		_update_anim(hor.length())
	_update_body(delta)

func add_push(v: Vector3) -> void:
	push += v

## Desmaio: animação de cair e fica sem controlo até `revive()`.
func faint() -> void:
	downed = true
	controllable = false
	if _anim and _anim.has_animation("Death"):
		_anim_name = "Death"
		_anim.play("Death", 0.1)

func revive() -> void:
	downed = false
	controllable = true
	_anim_name = ""
	_play("Idle")

## Direção de movimento no plano tangente, relativa à vista (câmara).
func move_direction(input: Vector2, u: Vector3) -> Vector3:
	if input.length() < 0.01:
		return Vector3.ZERO
	var ref := view.global_basis if view else global_basis
	var fwd := -ref.z
	fwd = fwd - u * fwd.dot(u)
	if fwd.length() < 0.01: # câmara a olhar a direito para baixo
		fwd = ref.y - u * ref.y.dot(u)
	fwd = fwd.normalized()
	var right := fwd.cross(u).normalized()
	return (right * input.x + fwd * input.y).limit_length(1.0)

## Roda o corpo pelo caminho mais curto até o eixo Y coincidir com `u`.
func _align(u: Vector3, weight: float) -> void:
	var cur := global_basis.y.normalized()
	if cur.dot(u) > 0.99999:
		return
	var q := Quaternion(cur, u)
	if weight < 1.0:
		q = Quaternion.IDENTITY.slerp(q, weight)
	global_basis = Basis(q * global_basis.get_rotation_quaternion()).orthonormalized()

var _jumped := false

## Salto: impulso ("Jump") ao sair do chão, pose no ar ("Jump_Idle"), aterragem ("Jump_Land")
## curta. Andar/correr com a velocidade da animação a acompanhar a velocidade real.
func _update_anim(speed: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		if _jumped and _anim and _anim.has_animation("Jump"):
			_jumped = false
			_play("Jump", 0.05)
		elif _anim_name != "Jump" or not _anim.is_playing():
			_play("Jump_Idle" if _anim and _anim.has_animation("Jump_Idle") else "Jump")
	elif not _was_on_floor:
		_land_t = 0.22
		_play("Jump_Land", 0.05)
	elif _land_t > 0.0:
		pass # deixa acabar a aterragem
	elif speed > walk_speed * 0.55:
		_play("Run")
		_anim.speed_scale = clampf(speed / walk_speed, 0.7, 1.4)
	elif speed > 0.4:
		_play("Walk")
		_anim.speed_scale = clampf(speed / (walk_speed * 0.45), 0.6, 1.3)
	else:
		_play("Idle")
	if _anim and _anim_name not in ["Run", "Walk"]:
		_anim.speed_scale = 1.0
	_was_on_floor = on_floor

## Braços a segurar a caixa (suave) e um pequeno amortecimento ao aterrar.
func _update_body(delta: float) -> void:
	_land_t = maxf(_land_t - delta, 0.0)
	var hold := carrying and not downed
	if _arms:
		_arms.influence = move_toward(_arms.influence, 1.0 if hold else 0.0, delta * 6.0)
	hand_crate.visible = hold and (_arms == null or _arms.influence > 0.6)
	var squash := 1.0 - 0.12 * sin(clampf(_land_t / 0.22, 0.0, 1.0) * PI)
	visual.scale = Vector3(2.0 - squash, squash, 2.0 - squash)

func _play(a: String, blend := 0.15) -> void:
	if _anim == null or a == _anim_name or not _anim.has_animation(a):
		return
	_anim_name = a
	_anim.play(a, blend)
