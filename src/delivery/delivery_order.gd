class_name DeliveryOrder
extends RefCounted
## Uma encomenda: apanhar no posto `from_post` e entregar no posto `to_post`.

enum State { OFFERED, ACCEPTED, CARRYING, DELIVERED }

var id: int
var kind := "normal"
var from_post: int
var to_post: int
var base_pay: int
var time_limit: float # segundos, contados a partir do momento em que se apanha a caixa
var elapsed := 0.0
var state := State.OFFERED
var paid := 0

func remaining() -> float:
	return time_limit - elapsed

func is_late() -> bool:
	return elapsed > time_limit
