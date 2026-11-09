class_name DeliverySession
extends RefCounted
## Regras das entregas (sem cena): colonos, ofertas, ciclo de vida das encomendas,
## relógio suave e pagamento. A cena só chama accept/pick_up/deliver/tick.

signal order_delivered(order: DeliveryOrder, on_time: bool)
signal order_failed(order: DeliveryOrder)
signal keycard_gained(total: int)
signal friendship_up(post: int, level: int)

const OFFER_COUNT := 3
const BASE_PAY := 40.0
const PAY_PER_M := 0.6
const TIME_PER_M := 1.0 / 8.0 # s por metro (rover com folga)
const TIME_SLACK := 20.0
const MIN_LATE_FACTOR := 0.3 # atrasado paga pelo menos 30%
const MIN_VALUE_FACTOR := 0.4 # uma encomenda maltratada vale pelo menos 40%
const PUSH_VALUE_LOSS := 0.15
## Regras por tipo: multiplicador do pagamento e do tempo.
const KINDS := {
	"normal": {"pay": 1.0, "time": 1.0},
	"urgent": {"pay": 1.5, "time": 0.6},
	"fragile": {"pay": 1.3, "time": 1.1},
	"perishable": {"pay": 1.4, "time": 1.0},
	"important": {"pay": 1.2, "time": 1.2},
	"special": {"pay": 1.8, "time": 1.2},
}
## Probabilidades das encomendas comuns no quadro.
const COMMON := [["normal", 0.45], ["urgent", 0.2], ["fragile", 0.2], ["perishable", 0.15]]
const KEYCARDS_PER_PLANET := 3
const DELIVERIES_PER_IMPORTANT := 2 # entregas entre encomendas importantes
## Pontos de amizade para cada nível (1..5).
const FRIEND_LEVELS := [0, 2, 4, 7, 10]
const SPECIAL_FROM_LEVEL := 3
const FRAGILE_LOSS_PER_BUMP := 0.25 # por unidade de força do solavanco
const PERISH_MIN := 0.5 # frescura mínima (no fim do tempo)

const NAMES := ["Nina", "Tomé", "Lua", "Bento", "Íris", "Zeca", "Maya", "Rui", "Olga", "Duda", "Kiko", "Sara"]

var wallet: Wallet
## [{name, post, reputation}]
var colonists: Array[Dictionary] = []
var offers: Array[DeliveryOrder] = []
var active: DeliveryOrder
## distances[i][j] = distância (m) entre os postos i e j.
var distances: Array = []
var keycards := 0
var important_given := 0
var since_important := 0
var _rng := RandomNumberGenerator.new()
var _next_id := 1

func _init(p_wallet: Wallet, post_distances: Array, p_seed: int) -> void:
	wallet = p_wallet
	distances = post_distances
	_rng.seed = hash(p_seed * 7919 + 13)
	var names := NAMES.duplicate()
	for i in distances.size():
		var n: String = names.pop_at(_rng.randi() % names.size())
		colonists.append({"name": n, "post": i, "reputation": 0}) # reputation = pontos de amizade
	refill_offers()

## Pagamento de `order` se for entregue com `elapsed` segundos. Nunca 0.
## Estado para o save: amizade de cada colono e KeyCards.
func to_dict() -> Dictionary:
	return {"reputation": colonists.map(func(c: Dictionary) -> int: return int(c.reputation)),
		"keycards": keycards, "important_given": important_given, "since_important": since_important}

func from_dict(d: Dictionary) -> void:
	var rep: Array = d.get("reputation", [])
	for i in mini(rep.size(), colonists.size()):
		colonists[i].reputation = int(rep[i])
	keycards = int(d.get("keycards", 0))
	important_given = int(d.get("important_given", 0))
	since_important = int(d.get("since_important", 0))

static func payment(base_pay: int, time_limit: float, elapsed: float) -> int:
	if elapsed <= time_limit:
		var spare := clampf(1.0 - elapsed / time_limit, 0.0, 1.0)
		return int(round(base_pay * (1.1 + 0.4 * spare)))
	var over := (elapsed - time_limit) / time_limit
	return maxi(1, int(round(base_pay * maxf(MIN_LATE_FACTOR, 1.0 - 0.7 * over))))

## Nível de amizade (1..5) com o colono do posto `post`.
func friendship_level(post: int) -> int:
	var pts: int = colonists[post].reputation
	var lvl := 1
	for i in FRIEND_LEVELS.size():
		if pts >= FRIEND_LEVELS[i]:
			lvl = i + 1
	return lvl

## Multiplicador de pagamento pela amizade com quem recebe (+10% por nível acima de 1).
func friendship_bonus(post: int) -> float:
	return 1.0 + 0.1 * (friendship_level(post) - 1)

func make_order(from_post: int, to_post: int, kind := "normal") -> DeliveryOrder:
	assert(from_post != to_post)
	var rule: Dictionary = KINDS[kind]
	var o := DeliveryOrder.new()
	o.id = _next_id
	_next_id += 1
	o.kind = kind
	o.from_post = from_post
	o.to_post = to_post
	var dist: float = distances[from_post][to_post]
	o.base_pay = int(round((BASE_PAY + dist * PAY_PER_M) * float(rule.pay) * friendship_bonus(to_post)))
	o.time_limit = (dist * TIME_PER_M + TIME_SLACK) * float(rule.time)
	# Algumas perecíveis levam colheitas da quinta (pagam mais).
	if kind == "perishable" and _rng.randf() < CROP_ORDER_CHANCE:
		o.crop = Wallet.CROP_KINDS[_rng.randi() % Wallet.CROP_KINDS.size()]
		o.base_pay = int(round(o.base_pay * CROP_ORDER_PAY))
	return o

const CROP_ORDER_CHANCE := 0.5
const CROP_ORDER_PAY := 1.5

## Pode aceitar já? (encomendas com colheita precisam de 1 na carteira)
func can_accept(o: DeliveryOrder) -> bool:
	return active == null and o in offers and (o.crop == "" or wallet.amount(o.crop) >= 1)

func _random_pair() -> Array:
	var n := distances.size()
	var a := _rng.randi() % n
	return [a, (a + 1 + _rng.randi() % (n - 1)) % n]

func _common_kind() -> String:
	var r := _rng.randf()
	for e in COMMON:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return "normal"

func has_offer(kind: String) -> bool:
	return offers.any(func(o: DeliveryOrder) -> bool: return o.kind == kind) or (active != null and active.kind == kind)

## Repõe o quadro: encomendas comuns, uma importante (KeyCard) de vez em quando, e uma especial
## de um colono amigo (nível ≥ 3).
func refill_offers() -> void:
	var n := distances.size()
	if n < 2:
		return
	if important_given < KEYCARDS_PER_PLANET and since_important >= DELIVERIES_PER_IMPORTANT and not has_offer("important"):
		var pi := _random_pair()
		offers.append(make_order(pi[0], pi[1], "important"))
		important_given += 1
		since_important = 0
	if not has_offer("special"):
		for c in colonists:
			if friendship_level(c.post) >= SPECIAL_FROM_LEVEL:
				var to: int = (int(c.post) + 1 + _rng.randi() % (n - 1)) % n
				offers.append(make_order(c.post, to, "special"))
				break
	while offers.size() < OFFER_COUNT:
		var pr := _random_pair()
		offers.append(make_order(pr[0], pr[1], _common_kind()))

func accept(o: DeliveryOrder) -> bool:
	if not can_accept(o):
		return false
	if o.crop != "" and not wallet.spend({o.crop: 1}):
		return false
	offers.erase(o)
	o.state = DeliveryOrder.State.ACCEPTED
	active = o
	refill_offers()
	return true

func pick_up() -> bool:
	if active == null or active.state != DeliveryOrder.State.ACCEPTED:
		return false
	active.state = DeliveryOrder.State.CARRYING
	active.elapsed = 0.0
	return true

func tick(delta: float) -> void:
	if active and active.state in [DeliveryOrder.State.CARRYING, DeliveryOrder.State.STOLEN, DeliveryOrder.State.DROPPED]:
		active.elapsed += delta
		if active.kind == "perishable":
			active.freshness = maxf(PERISH_MIN, 1.0 - (1.0 - PERISH_MIN) * active.elapsed / active.time_limit)

## Solavanco do rover (força como em Rover.bumped): estraga as encomendas frágeis.
## Multiplicador da perda de valor em embates (melhoria de carga do rover).
var cargo_factor := 1.0
## Multiplicador do pagamento na hora da entrega (à noite os colonos pagam mais, #37).
var pay_factor := 1.0

func bump_active(strength: float) -> void:
	if carrying() and active.kind == "fragile":
		active.value_factor = maxf(active.value_factor - strength * FRAGILE_LOSS_PER_BUMP * cargo_factor, MIN_VALUE_FACTOR)

func carrying() -> bool:
	return active != null and active.state == DeliveryOrder.State.CARRYING

## Um empurrão (criatura) estraga a encomenda que se leva: perde valor.
func damage_active(loss := PUSH_VALUE_LOSS) -> void:
	if carrying():
		active.value_factor = maxf(active.value_factor - loss * cargo_factor, MIN_VALUE_FACTOR)

## Uma criatura rouba a caixa que se leva.
func steal() -> bool:
	if not carrying():
		return false
	damage_active(PUSH_VALUE_LOSS)
	active.state = DeliveryOrder.State.STOLEN
	return true

## A caixa roubada cai no chão em `pos` (a criatura largou-a).
func drop(pos: Vector3) -> bool:
	if active == null or active.state != DeliveryOrder.State.STOLEN:
		return false
	active.state = DeliveryOrder.State.DROPPED
	active.drop_position = pos
	return true

## O jogador volta a apanhar a caixa caída.
func recover() -> bool:
	if active == null or active.state != DeliveryOrder.State.DROPPED:
		return false
	active.state = DeliveryOrder.State.CARRYING
	return true

## Entrega a encomenda ativa (o jogador está no posto de destino). Devolve o pagamento.
func deliver() -> int:
	if active == null or active.state != DeliveryOrder.State.CARRYING:
		return 0
	var o := active
	var on_time := not o.is_late()
	o.paid = maxi(1, int(round(payment(o.base_pay, o.time_limit, o.elapsed) * o.value_factor * o.freshness * pay_factor)))
	o.state = DeliveryOrder.State.DELIVERED
	wallet.add(Wallet.CREDITS, o.paid)
	since_important += 1
	if o.kind == "important":
		keycards += 1
		keycard_gained.emit(keycards)
	if on_time:
		var before := friendship_level(o.to_post)
		colonists[o.to_post].reputation += 2 if o.kind in ["important", "special"] else 1
		if friendship_level(o.to_post) > before:
			friendship_up.emit(o.to_post, friendship_level(o.to_post))
	active = null
	order_delivered.emit(o, on_time)
	return o.paid

## A encomenda ativa falha (rover explodiu, jogador desmaiou): não paga e liberta o jogador.
func fail_active() -> bool:
	if active == null:
		return false
	var o := active
	o.state = DeliveryOrder.State.FAILED
	o.paid = 0
	active = null
	order_failed.emit(o)
	return true

## Posto onde o jogador tem de ir a seguir, ou -1.
func target_post() -> int:
	if active == null:
		return -1
	return active.from_post if active.state == DeliveryOrder.State.ACCEPTED else active.to_post

func lair_open() -> bool:
	return keycards >= KEYCARDS_PER_PLANET

func colonist_name(post: int) -> String:
	return colonists[post].name
