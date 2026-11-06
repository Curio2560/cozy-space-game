class_name DeliverySession
extends RefCounted
## Regras das entregas (sem cena): colonos, ofertas, ciclo de vida das encomendas,
## relógio suave e pagamento. A cena só chama accept/pick_up/deliver/tick.

signal order_delivered(order: DeliveryOrder, on_time: bool)
signal order_failed(order: DeliveryOrder)

const OFFER_COUNT := 3
const BASE_PAY := 40.0
const PAY_PER_M := 0.6
const TIME_PER_M := 1.0 / 8.0 # s por metro (rover com folga)
const TIME_SLACK := 20.0
const MIN_LATE_FACTOR := 0.3 # atrasado paga pelo menos 30%
const NAMES := ["Nina", "Tomé", "Lua", "Bento", "Íris", "Zeca", "Maya", "Rui", "Olga", "Duda", "Kiko", "Sara"]

var wallet: Wallet
## [{name, post, reputation}]
var colonists: Array[Dictionary] = []
var offers: Array[DeliveryOrder] = []
var active: DeliveryOrder
## distances[i][j] = distância (m) entre os postos i e j.
var distances: Array = []
var _rng := RandomNumberGenerator.new()
var _next_id := 1

func _init(p_wallet: Wallet, post_distances: Array, p_seed: int) -> void:
	wallet = p_wallet
	distances = post_distances
	_rng.seed = hash(p_seed * 7919 + 13)
	var names := NAMES.duplicate()
	for i in distances.size():
		var n: String = names.pop_at(_rng.randi() % names.size())
		colonists.append({"name": n, "post": i, "reputation": 0})
	refill_offers()

## Pagamento de `order` se for entregue com `elapsed` segundos. Nunca 0.
static func payment(base_pay: int, time_limit: float, elapsed: float) -> int:
	if elapsed <= time_limit:
		var spare := clampf(1.0 - elapsed / time_limit, 0.0, 1.0)
		return int(round(base_pay * (1.1 + 0.4 * spare)))
	var over := (elapsed - time_limit) / time_limit
	return maxi(1, int(round(base_pay * maxf(MIN_LATE_FACTOR, 1.0 - 0.7 * over))))

func make_order(from_post: int, to_post: int) -> DeliveryOrder:
	assert(from_post != to_post)
	var o := DeliveryOrder.new()
	o.id = _next_id
	_next_id += 1
	o.from_post = from_post
	o.to_post = to_post
	var dist: float = distances[from_post][to_post]
	o.base_pay = int(round(BASE_PAY + dist * PAY_PER_M))
	o.time_limit = dist * TIME_PER_M + TIME_SLACK
	return o

func refill_offers() -> void:
	var n := distances.size()
	while offers.size() < OFFER_COUNT and n >= 2:
		var a := _rng.randi() % n
		var b := (a + 1 + _rng.randi() % (n - 1)) % n
		offers.append(make_order(a, b))

func accept(o: DeliveryOrder) -> bool:
	if active != null or o not in offers:
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
	if active and active.state == DeliveryOrder.State.CARRYING:
		active.elapsed += delta

## Entrega a encomenda ativa (o jogador está no posto de destino). Devolve o pagamento.
func deliver() -> int:
	if active == null or active.state != DeliveryOrder.State.CARRYING:
		return 0
	var o := active
	var on_time := not o.is_late()
	o.paid = payment(o.base_pay, o.time_limit, o.elapsed)
	o.state = DeliveryOrder.State.DELIVERED
	wallet.add(Wallet.CREDITS, o.paid)
	if on_time:
		colonists[o.to_post].reputation += 1
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

func colonist_name(post: int) -> String:
	return colonists[post].name
