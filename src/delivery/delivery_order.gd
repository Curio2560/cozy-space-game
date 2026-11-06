class_name DeliveryOrder
extends RefCounted
## Uma encomenda: apanhar no posto `from_post` e entregar no posto `to_post`.

enum State { OFFERED, ACCEPTED, CARRYING, DELIVERED, FAILED, STOLEN, DROPPED }

var id: int
## normal, urgent, fragile, perishable, important (dá um KeyCard), special (amizade ≥ 3)
var kind := "normal"
## Frescura (encomendas perecíveis): desce com o tempo e multiplica o pagamento.
var freshness := 1.0
var from_post: int
var to_post: int
var base_pay: int
var time_limit: float # segundos, contados a partir do momento em que se apanha a caixa
var elapsed := 0.0
var state := State.OFFERED
var paid := 0
## Fração do pagamento que ainda vale (empurrões e roubos estragam a encomenda).
var value_factor := 1.0
## Onde a caixa ficou no chão (estado DROPPED), em coordenadas globais.
var drop_position := Vector3.ZERO

func remaining() -> float:
	return time_limit - elapsed

func is_late() -> bool:
	return elapsed > time_limit
