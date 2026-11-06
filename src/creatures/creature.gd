class_name Creature
extends Node3D
## Criatura que vive à superfície do planeta (sem física: anda sobre a função de altura).
## Passeia calma; se o alvo (jogador ou rover) se aproximar persegue-o e ataca; às vezes rouba a
## caixa e foge com ela, largando-a se lhe tocarem ou ao fim de CARRY_TIME. Só pensa quando o
## alvo está perto (poupa o telemóvel).

signal attacked(creature: Creature)
signal dropped_crate(creature: Creature, at: Vector3)

enum Mode { WANDER, CHASE, FLEE, KNOCKED }

const NOTICE := 7.0 # de dia só repara em quem está perto
const GIVE_UP := 15.0
const ATTACK_RANGE := 1.8
const TOUCH_RANGE := 2.0
const COOLDOWN := 2.4
const CARRY_TIME := 20.0
const ACTIVE_RANGE := 75.0

var id: String
var planet: Planet
## Devolve o nó a perseguir (jogador ou rover).
var target: Callable
var steal_chance := 0.3
var mode := Mode.WANDER
var dir := Vector3.UP # direção no espaço do planeta
var heading := Vector3.FORWARD # tangente no espaço do planeta
var carrying := false
var model: Node3D

var _rng := RandomNumberGenerator.new()
var _cooldown := 0.0
var _turn_timer := 0.0
var _pause := 0.0
var _carry_timer := 0.0
var _knock_timer := 0.0
var _anim_role := ""
var _ap: AnimationPlayer
var _speed_k := 1.0

func setup(p_id: String, p_planet: Planet, p_dir: Vector3, biome: String, seed_value: int) -> void:
	id = p_id
	planet = p_planet
	dir = p_dir.normalized()
	_rng.seed = seed_value
	model = CreatureCatalog.instantiate(id, biome)
	add_child(model)
	_ap = CreatureCatalog.animation_player(model)
	var fam := CreatureCatalog.family(id)
	_speed_k = {"big": 1.0, "blob": 0.8, "flying": 1.15}[fam]
	heading = SphereMath.basis_from_up(dir, _rng.randf() * TAU).z
	_place()

func speed() -> float:
	match mode:
		Mode.CHASE:
			return 3.6 * _speed_k
		Mode.FLEE:
			return 4.4 * _speed_k
		Mode.KNOCKED:
			return 2.5
	return 0.0 if _pause > 0.0 else 1.3 * _speed_k

## Põe a criatura noutro sítio do planeta (direção no espaço do planeta), já posicionada.
func teleport_to(p_dir: Vector3) -> void:
	dir = p_dir.normalized()
	heading = (heading - dir * heading.dot(dir)).normalized()
	if heading.length() < 0.5:
		heading = SphereMath.basis_from_up(dir).z
	mode = Mode.WANDER
	_place()

## Atingida (p. ex. pelo rover a alta velocidade): reage e foge um bocado.
func knock(from: Vector3) -> void:
	mode = Mode.KNOCKED
	_knock_timer = 1.6
	_cooldown = COOLDOWN
	_face_away_from(from)
	_play("hit", true)
	if carrying:
		drop()

## Fica com a caixa roubada e foge.
func take_crate() -> void:
	carrying = true
	_carry_timer = CARRY_TIME
	mode = Mode.FLEE

func drop() -> void:
	if not carrying:
		return
	carrying = false
	mode = Mode.WANDER
	_cooldown = COOLDOWN * 2.0
	dropped_crate.emit(self, global_position + _up_global() * 0.4)

func _physics_process(delta: float) -> void:
	if planet == null or not target.is_valid():
		return
	var t: Node3D = target.call()
	if t == null:
		return
	var dist := global_position.distance_to(t.global_position)
	var awake := dist < ACTIVE_RANGE or carrying
	visible = dist < ACTIVE_RANGE * 1.3
	if _ap:
		_ap.speed_scale = 1.0 if awake else 0.0
	if not awake:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	var to_t := planet.to_local(t.global_position).normalized()
	match mode:
		Mode.WANDER:
			_wander(delta)
			if dist < NOTICE and _cooldown <= 0.0:
				mode = Mode.CHASE
		Mode.CHASE:
			_steer_towards(to_t, delta, 6.0)
			if dist > GIVE_UP:
				mode = Mode.WANDER
			elif dist < ATTACK_RANGE and _cooldown <= 0.0:
				_cooldown = COOLDOWN
				_play("attack", true)
				attacked.emit(self)
				if not carrying:
					mode = Mode.WANDER
					_face_away_from(t.global_position)
		Mode.FLEE:
			_steer_towards(-to_t, delta, 4.0) # afasta-se do alvo
			_carry_timer -= delta
			if dist < TOUCH_RANGE or _carry_timer <= 0.0:
				_play("hit", true)
				drop()
		Mode.KNOCKED:
			_knock_timer -= delta
			if _knock_timer <= 0.0:
				mode = Mode.WANDER
	_move(delta)
	_update_anim()

func _wander(delta: float) -> void:
	_pause = maxf(_pause - delta, 0.0)
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_turn_timer = _rng.randf_range(2.0, 5.0)
		if _rng.randf() < 0.3:
			_pause = _rng.randf_range(1.0, 2.5)
		heading = heading.rotated(dir, _rng.randf_range(-1.2, 1.2))

func _steer_towards(target_dir: Vector3, delta: float, rate: float) -> void:
	var want := target_dir - dir * target_dir.dot(dir)
	if want.length() < 0.0001:
		return
	heading = heading.slerp(want.normalized(), clampf(rate * delta, 0.0, 1.0)).normalized()

func _face_away_from(p: Vector3) -> void:
	var away := -(planet.to_local(p).normalized())
	away = away - dir * away.dot(dir)
	if away.length() > 0.0001:
		heading = away.normalized()

func _move(delta: float) -> void:
	var step := speed() * delta / planet.data.radius
	if step > 0.0:
		dir = (dir + heading * step).normalized()
	heading = (heading - dir * heading.dot(dir)).normalized()
	_place()

func _place() -> void:
	var z := heading
	var y := dir
	var x := y.cross(z).normalized()
	var b := Basis(x, y, x.cross(y)).orthonormalized()
	global_transform = planet.global_transform * Transform3D(b, planet.data.surface_point(dir))

func _up_global() -> Vector3:
	return (global_position - planet.global_position).normalized()

func _update_anim() -> void:
	if _knock_timer > 0.0 and mode == Mode.KNOCKED:
		return
	var role := "idle"
	if mode == Mode.CHASE or mode == Mode.FLEE:
		role = "run"
	elif speed() > 0.1:
		role = "move"
	if _ap and _ap.is_playing() and _anim_role in ["attack", "hit"] and _ap.current_animation_position < _ap.current_animation_length * 0.9:
		return
	_play(role)

func _play(role: String, force := false) -> void:
	if _ap == null or (role == _anim_role and not force):
		return
	var n := CreatureCatalog.anim(model, role)
	if n != "":
		_anim_role = role
		_ap.play(n, 0.15)
