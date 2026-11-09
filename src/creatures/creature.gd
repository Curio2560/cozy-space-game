class_name Creature
extends Node3D
## Criatura que vive à superfície do planeta (sem física: anda sobre a função de altura).
##
## Inteligência:
## - Só ganham agro quando o alvo leva uma encomenda. Sem caixa ninguém ataca.
## - Personalidade: AGGRESSIVE (com caixa: persegue e ataca), THIEF (com caixa: persegue e rouba),
##   CURIOUS (aproxima-se, fica a ver, não ataca), TIMID (foge de quem chega).
## - Território: passeia à volta de casa; desiste de perseguir se se afastar demasiado.
## - Ataque avisado: pára e prepara o golpe (WINDUP); só acerta se o alvo ainda estiver perto.
## - Contorna árvores, pedregulhos e estruturas; afasta-se das outras criaturas.
## - Salta para o lado quando o rover vem depressa na sua direção.
## Só pensa quando o alvo está perto (poupa o telemóvel).

signal attacked(creature: Creature)
signal dropped_crate(creature: Creature, at: Vector3)
## Criaturas da noite (#38): golpe num alvo do ataque (`key` = "player" ou índice do slot).
signal raid_hit(creature: Creature, key: Variant)
signal died(creature: Creature)

enum Mode { WANDER, CHASE, WINDUP, WATCH, FLEE, CARRY, KNOCKED, DODGE, RETURN }
enum Personality { AGGRESSIVE, THIEF, CURIOUS, TIMID }

const ATTACK_RANGE := 1.8
const HIT_RANGE := 2.4 # no fim da preparação, o golpe acerta se o alvo ainda estiver aqui
const WINDUP_TIME := 0.6
const TOUCH_RANGE := 2.0
const STEAL_GRACE := 1.0 # s depois de roubar em que tocar ainda não a faz largar (tem de fugir)
const COOLDOWN := 2.6
const CARRY_TIME := 20.0
const ACTIVE_RANGE := 75.0
const TERRITORY_M := 26.0 # passeia até esta distância de casa
const LEASH_M := 38.0 # persegue no máximo até esta distância de casa
const WATCH_DISTANCE := 4.5 # os curiosos ficam a esta distância
const SEPARATION_M := 2.2

## Até onde cada personalidade repara no alvo (de dia, com encomenda para os hostis).
const NOTICE := {Personality.AGGRESSIVE: 10.0, Personality.THIEF: 13.0, Personality.CURIOUS: 10.0, Personality.TIMID: 7.0}
const STEAL := {Personality.AGGRESSIVE: 0.15, Personality.THIEF: 0.85, Personality.CURIOUS: 0.0, Personality.TIMID: 0.0}

var id: String
var planet: Planet
## Devolve o nó a perseguir (jogador ou rover).
var target: Callable
## Se o alvo leva uma caixa (para os ladrões).
var target_has_crate: Callable
## As outras criaturas (para não se amontoarem).
var flock: Array = []
var personality := Personality.AGGRESSIVE
var steal_chance := 0.15
var mode := Mode.WANDER
var dir := Vector3.UP # direção no espaço do planeta
var home := Vector3.UP
var heading := Vector3.FORWARD # tangente no espaço do planeta
var carrying := false
var model: Node3D

var _rng := RandomNumberGenerator.new()
var _cooldown := 0.0
var _turn_timer := 0.0
var _pause := 0.0
var _timer := 0.0
var _anim_role := ""
var _ap: AnimationPlayer
var _speed_k := 1.0
## À noite as hostis atacam mesmo sem encomenda (grill r2 Q15).
var night_hostile := false
## Criatura de uma vaga da noite: vai direta ao posto, ataca edifícios e o jogador perto.
var raider := false
## Devolve o alvo do ataque: [posição global, alcance do golpe em m, chave] ou [] se não houver.
var raid_target: Callable
var health := 30.0
var max_health := 30.0
var dead := false
const RAID_SPEED := 3.0
const RAID_WINDUP := 0.7
const RAID_COOLDOWN := 1.6

func setup(p_id: String, p_planet: Planet, p_dir: Vector3, biome: String, seed_value: int) -> void:
	id = p_id
	planet = p_planet
	dir = p_dir.normalized()
	home = dir
	_rng.seed = seed_value
	model = CreatureCatalog.instantiate(id, biome)
	add_child(model)
	_ap = CreatureCatalog.animation_player(model)
	var fam := CreatureCatalog.family(id)
	_speed_k = {"big": 1.0, "blob": 0.8, "flying": 1.15}[fam]
	set_personality(_pick_personality(fam))
	heading = SphereMath.basis_from_up(dir, _rng.randf() * TAU).z
	_place()

func set_personality(p: Personality) -> void:
	personality = p
	steal_chance = STEAL[p]

func _pick_personality(fam: String) -> Personality:
	var table: Array = {
		"big": [[Personality.AGGRESSIVE, 0.5], [Personality.CURIOUS, 0.3], [Personality.THIEF, 0.2]],
		"blob": [[Personality.TIMID, 0.45], [Personality.CURIOUS, 0.4], [Personality.THIEF, 0.15]],
		"flying": [[Personality.THIEF, 0.5], [Personality.AGGRESSIVE, 0.3], [Personality.CURIOUS, 0.2]],
	}[fam]
	var r := _rng.randf()
	for e in table:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return table[0][0]

func speed() -> float:
	match mode:
		Mode.CHASE, Mode.CARRY:
			return (3.6 if mode == Mode.CHASE else 4.4) * _speed_k
		Mode.FLEE, Mode.DODGE:
			return 4.2 * _speed_k
		Mode.KNOCKED:
			return 2.5
		Mode.RETURN:
			return 2.0 * _speed_k
		Mode.WINDUP, Mode.WATCH:
			return 0.0
	return 0.0 if _pause > 0.0 else 1.3 * _speed_k

## Põe a criatura noutro sítio do planeta (direção no espaço do planeta), já posicionada.
## Também passa a ser a sua casa.
func teleport_to(p_dir: Vector3) -> void:
	dir = p_dir.normalized()
	home = dir
	heading = (heading - dir * heading.dot(dir)).normalized()
	if heading.length() < 0.5:
		heading = SphereMath.basis_from_up(dir).z
	mode = Mode.WANDER
	_place()

## Atingida (p. ex. pelo rover a alta velocidade): reage e foge um bocado.
func knock(from: Vector3) -> void:
	mode = Mode.KNOCKED
	_timer = 1.6
	_cooldown = COOLDOWN
	_face_away_from(from)
	_play("hit", true)
	if carrying:
		drop()

## Fica com a caixa roubada e foge.
func take_crate() -> void:
	carrying = true
	_timer = CARRY_TIME
	_grace = STEAL_GRACE
	mode = Mode.CARRY

var _grace := 0.0

func drop() -> void:
	if not carrying:
		return
	carrying = false
	mode = Mode.RETURN
	_cooldown = COOLDOWN * 2.0
	dropped_crate.emit(self, global_position + _up_global() * 0.4)

## Leva dano (tiros do mech, torres). A 0 morre (uma vez só).
func take_hit(dmg: float) -> void:
	if dead:
		return
	health -= dmg
	if health <= 0.0:
		health = 0.0
		dead = true
		if carrying:
			drop()
		_play("death", true)
		died.emit(self)
		var tw := create_tween()
		tw.tween_interval(0.9)
		tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.35)
		tw.tween_callback(queue_free)
	else:
		_play("hit", true)

## Ataque da noite: segue o alvo dado por `raid_target` e golpeia quando chega perto.
func _raid(delta: float) -> void:
	if not raid_target.is_valid():
		return
	var tgt: Array = raid_target.call()
	_cooldown = maxf(_cooldown - delta, 0.0)
	if tgt.is_empty():
		_wander(delta, planet.data.arc_m(dir, home))
		_move(delta, 1.3 * _speed_k)
		_update_anim()
		return
	var pos: Vector3 = tgt[0]
	var reach: float = tgt[1]
	var to_t := planet.to_local(pos).normalized()
	var dist := planet.data.arc_m(dir, to_t)
	if mode == Mode.WINDUP:
		_steer_towards(to_t, delta, 10.0)
		_timer -= delta
		if _timer <= 0.0:
			_cooldown = RAID_COOLDOWN
			mode = Mode.CHASE
			if dist < reach + 0.8:
				raid_hit.emit(self, tgt[2])
		_place()
		return
	mode = Mode.CHASE
	_steer_towards(to_t, delta, 6.0)
	if dist < reach:
		if _cooldown <= 0.0:
			mode = Mode.WINDUP
			_timer = RAID_WINDUP
			_play("attack", true)
		_place()
		return
	_move(delta, RAID_SPEED * _speed_k)
	_update_anim()

func _physics_process(delta: float) -> void:
	if planet == null or dead:
		return
	if raider:
		_raid(delta)
		return
	if not target.is_valid():
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
	var from_home := planet.data.arc_m(dir, home)
	if _rover_incoming(t, dist) and mode in [Mode.WANDER, Mode.WATCH, Mode.CHASE, Mode.RETURN]:
		mode = Mode.DODGE
		_timer = 0.9
		var tv := (t as RigidBody3D).linear_velocity
		heading = (planet.global_basis.inverse() * tv).cross(dir).normalized() * (1.0 if _rng.randf() < 0.5 else -1.0)
	match mode:
		Mode.WANDER:
			_wander(delta, from_home)
			if _cooldown <= 0.0 and dist < _notice_range():
				_react_to_target()
		Mode.CHASE:
			_steer_towards(to_t, delta, 6.0)
			if dist > _notice_range() * 2.0 or from_home > LEASH_M or not _hostile():
				mode = Mode.RETURN
			elif dist < ATTACK_RANGE and _cooldown <= 0.0:
				mode = Mode.WINDUP
				_timer = WINDUP_TIME
				_play("attack", true)
		Mode.WINDUP:
			_steer_towards(to_t, delta, 10.0) # vira-se para o alvo enquanto prepara
			_timer -= delta
			if _timer <= 0.0:
				_cooldown = COOLDOWN
				if dist < HIT_RANGE and _hostile():
					attacked.emit(self)
				if not carrying:
					mode = Mode.RETURN if personality != Personality.AGGRESSIVE else Mode.WANDER
					_face_away_from(t.global_position)
		Mode.WATCH:
			_steer_towards(to_t, delta, 5.0)
			if dist < WATCH_DISTANCE * 0.6:
				mode = Mode.FLEE
				_timer = 1.5
			elif dist > _notice_range() * 1.5 or from_home > LEASH_M:
				mode = Mode.RETURN
			elif dist > WATCH_DISTANCE * 1.4:
				_steer_towards(to_t, delta, 4.0)
				_move(delta, 1.2 * _speed_k)
				_update_anim()
				return
		Mode.FLEE:
			_steer_towards(-to_t, delta, 6.0)
			_timer -= delta
			if _timer <= 0.0 and dist > _notice_range():
				mode = Mode.RETURN
		Mode.CARRY:
			_steer_towards(-to_t, delta, 4.0)
			_timer -= delta
			_grace -= delta
			if (dist < TOUCH_RANGE and _grace <= 0.0) or _timer <= 0.0:
				_play("hit", true)
				drop()
		Mode.KNOCKED, Mode.DODGE:
			_timer -= delta
			if _timer <= 0.0:
				mode = Mode.RETURN
		Mode.RETURN:
			_steer_towards(home, delta, 3.0)
			if from_home < TERRITORY_M * 0.5:
				mode = Mode.WANDER
			elif _cooldown <= 0.0 and dist < _notice_range() * 0.7 and _hostile():
				mode = Mode.CHASE
	_move(delta, speed())
	_update_anim()

## O que fazer quando repara no alvo, conforme a personalidade.
func _react_to_target() -> void:
	match personality:
		Personality.AGGRESSIVE, Personality.THIEF:
			if _hostile():
				mode = Mode.CHASE
		Personality.CURIOUS:
			mode = Mode.WATCH
		Personality.TIMID:
			mode = Mode.FLEE
			_timer = 2.0

## O alvo leva uma encomenda?
func _target_has_crate() -> bool:
	return target_has_crate.is_valid() and target_has_crate.call()

## Só as personalidades hostis, e só quando o alvo leva uma encomenda.
func _hostile() -> bool:
	return personality in [Personality.AGGRESSIVE, Personality.THIEF] and (_target_has_crate() or night_hostile)

func _notice_range() -> float:
	return NOTICE[personality]

## O rover vem depressa na direção da criatura?
func _rover_incoming(t: Node3D, dist: float) -> bool:
	if not (t is RigidBody3D) or dist > 9.0:
		return false
	var v := (t as RigidBody3D).linear_velocity
	return v.length() > 6.0 and v.normalized().dot((global_position - t.global_position).normalized()) > 0.7

func _wander(delta: float, from_home: float) -> void:
	_pause = maxf(_pause - delta, 0.0)
	_turn_timer -= delta
	if from_home > TERRITORY_M:
		_steer_towards(home, delta, 2.0) # volta para o seu território
	elif _turn_timer <= 0.0:
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

## Desvia o rumo de obstáculos à frente e de outras criaturas muito perto.
func _avoid() -> void:
	var r := planet.data.radius
	var ahead := (dir + heading * (1.8 / r)).normalized()
	var push := Vector3.ZERO
	for o in planet.data.obstacles_near(ahead):
		var op: Vector3 = (o[0] as Vector3) / r
		var gap := planet.data.arc_m(ahead, op) - float(o[1]) - 0.6
		if gap < 0.0:
			var away := ahead - op
			push += (away - dir * away.dot(dir)).normalized() * (-gap + 0.5)
	for c in flock:
		if c == self or not is_instance_valid(c):
			continue
		var cd: Vector3 = (c as Creature).dir
		var m := planet.data.arc_m(dir, cd)
		if m < SEPARATION_M and m > 0.001:
			var away2 := dir - cd
			push += (away2 - dir * away2.dot(dir)).normalized() * (SEPARATION_M - m)
	if push.length() > 0.0001:
		heading = (heading + push * 0.8).normalized()

func _move(delta: float, spd: float) -> void:
	if spd > 0.0:
		_avoid()
		dir = (dir + heading * (spd * delta / planet.data.radius)).normalized()
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
	if mode == Mode.KNOCKED or mode == Mode.WINDUP:
		return
	var role := "idle"
	if mode in [Mode.CHASE, Mode.FLEE, Mode.CARRY, Mode.DODGE]:
		role = "run"
	elif speed() > 0.1 or (mode == Mode.WATCH):
		role = "move" if speed() > 0.1 else "idle"
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
