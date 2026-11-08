class_name Outpost
extends RefCounted
## Regras do posto avançado (puras, sem cena): slots fixos com edifícios, energia, produção
## por tempo para o armazém de cada edifício, recolha com um toque.
## - Cada edifício gasta 1 de energia; cada painel solar dá 3. Sem energia que chegue, tudo
##   produz a 50%.
## - Cada edifício guarda até CAPACITY (+ STORAGE_BONUS por armazém) do que produz.

signal changed

const START_SLOTS := 6
const MAX_SLOTS := 10
const CAPACITY := 20
const STORAGE_BONUS := 20
const LOW_POWER := 0.5

## kind -> {cost, produces, period (s), consumes ({recurso: n} por unidade), energy (+dá / -gasta)}
const BUILDINGS := {
	"miner": {"cost": {Wallet.CREDITS: 120}, "produces": Wallet.ORE, "period": 20.0, "consumes": {}, "energy": -1},
	"lab": {"cost": {Wallet.CREDITS: 250, Wallet.ORE: 10}, "produces": Wallet.CRYSTAL, "period": 40.0, "consumes": {Wallet.ORE: 2}, "energy": -1},
	"research": {"cost": {Wallet.CREDITS: 300}, "produces": Wallet.DATA, "period": 60.0, "consumes": {}, "energy": -1},
	"solar": {"cost": {Wallet.CREDITS: 80}, "produces": "", "period": 0.0, "consumes": {}, "energy": 3},
	"storage": {"cost": {Wallet.CREDITS: 150}, "produces": "", "period": 0.0, "consumes": {}, "energy": -1},
	"turret": {"cost": {Wallet.CREDITS: 200}, "produces": "", "period": 0.0, "consumes": {}, "energy": -1},
}
const ORDER := ["miner", "lab", "research", "solar", "storage", "turret"]

## Torre laser (#40): estatísticas por nível (1..3). Sem energia que chegue dispara a metade.
const TURRET_LEVELS := [
	{"damage": 5.0, "interval": 0.5, "range": 20.0},
	{"damage": 8.0, "interval": 0.4, "range": 24.0},
	{"damage": 12.0, "interval": 0.3, "range": 28.0},
]
## Custo para subir ao nível 2 e ao nível 3.
const TURRET_UPGRADE := [
	{Wallet.CREDITS: 300, Wallet.ORE: 10},
	{Wallet.CREDITS: 600, Wallet.CRYSTAL: 5},
]

var slot_count := START_SLOTS
## Um por slot (até MAX_SLOTS): {kind: "" (vazio) ou tipo, stored: int, progress: float, level: int}
var slots: Array[Dictionary] = []

func _init() -> void:
	for i in MAX_SLOTS:
		slots.append(_empty_slot())

func is_empty(i: int) -> bool:
	return slots[i].kind == ""

func count(kind: String) -> int:
	var n := 0
	for i in slot_count:
		if slots[i].kind == kind:
			n += 1
	return n

func energy_supply() -> int:
	var e := 0
	for i in slot_count:
		var k: String = slots[i].kind
		if k != "" and int(BUILDINGS[k].energy) > 0:
			e += int(BUILDINGS[k].energy)
	return e

func energy_demand() -> int:
	var e := 0
	for i in slot_count:
		var k: String = slots[i].kind
		if k != "" and int(BUILDINGS[k].energy) < 0:
			e -= int(BUILDINGS[k].energy)
	return e

## 1 com energia que chegue, LOW_POWER sem.
func power_factor() -> float:
	return 1.0 if energy_supply() >= energy_demand() else LOW_POWER

func capacity() -> int:
	return CAPACITY + STORAGE_BONUS * count("storage")

## Constrói `kind` no slot `i` se estiver vazio e houver dinheiro. Atómico.
func build(i: int, kind: String, wallet: Wallet) -> bool:
	if i < 0 or i >= slot_count or not is_empty(i) or not BUILDINGS.has(kind):
		return false
	if not wallet.spend(BUILDINGS[kind].cost):
		return false
	slots[i] = {"kind": kind, "stored": 0, "progress": 0.0, "level": 1}
	changed.emit()
	return true

static func _empty_slot() -> Dictionary:
	return {"kind": "", "stored": 0, "progress": 0.0, "level": 1}

func level(i: int) -> int:
	return int(slots[i].get("level", 1))

## Custo da próxima melhoria do slot `i` ({} se não der: não é torre ou já está no máximo).
func upgrade_cost(i: int) -> Dictionary:
	if i < 0 or i >= slot_count or slots[i].kind != "turret" or level(i) >= TURRET_LEVELS.size():
		return {}
	return TURRET_UPGRADE[level(i) - 1]

## Sobe a torre do slot `i` um nível, se houver dinheiro. Atómico.
func upgrade(i: int, wallet: Wallet) -> bool:
	var cost := upgrade_cost(i)
	if cost.is_empty() or not wallet.spend(cost):
		return false
	slots[i].level = level(i) + 1
	changed.emit()
	return true

## Estatísticas da torre do slot `i` agora (dano, intervalo, alcance), com a energia.
func turret_stats(i: int) -> Dictionary:
	var st: Dictionary = TURRET_LEVELS[clampi(level(i), 1, TURRET_LEVELS.size()) - 1].duplicate()
	st.interval = float(st.interval) / power_factor()
	return st

## Índices dos slots com torre.
func turrets() -> Array[int]:
	var out: Array[int] = []
	for i in slot_count:
		if slots[i].kind == "turret":
			out.append(i)
	return out

## Avança a produção `delta` segundos. O laboratório gasta minério da carteira por unidade
## (se não houver, espera).
func tick(delta: float, wallet: Wallet) -> void:
	var f := power_factor()
	var cap := capacity()
	var any := false
	for i in slot_count:
		var s: Dictionary = slots[i]
		if s.kind == "":
			continue
		var b: Dictionary = BUILDINGS[s.kind]
		if b.produces == "" or int(s.stored) >= cap:
			continue
		s.progress = float(s.progress) + delta * f
		while float(s.progress) >= float(b.period) and int(s.stored) < cap:
			if not (b.consumes as Dictionary).is_empty() and not wallet.spend(b.consumes):
				s.progress = float(b.period) # pronto, à espera de material
				break
			s.progress = float(s.progress) - float(b.period)
			s.stored = int(s.stored) + 1
			any = true
	if any:
		changed.emit()

## Passa o que está guardado no slot `i` para a carteira. Devolve quanto.
func collect(i: int, wallet: Wallet) -> int:
	var s: Dictionary = slots[i]
	if s.kind == "" or int(s.stored) <= 0:
		return 0
	var n := int(s.stored)
	wallet.add(BUILDINGS[s.kind].produces, n)
	s.stored = 0
	changed.emit()
	return n

func collect_all(wallet: Wallet) -> int:
	var n := 0
	for i in slot_count:
		n += collect(i, wallet)
	return n

## +2 slots (upgrade do posto), até MAX_SLOTS.
func add_slots(n := 2) -> bool:
	if slot_count >= MAX_SLOTS:
		return false
	slot_count = mini(slot_count + n, MAX_SLOTS)
	changed.emit()
	return true

func to_dict() -> Dictionary:
	return {"slot_count": slot_count, "slots": slots.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	slot_count = clampi(int(d.get("slot_count", START_SLOTS)), START_SLOTS, MAX_SLOTS)
	var arr: Array = d.get("slots", [])
	for i in MAX_SLOTS:
		if i < arr.size() and arr[i] is Dictionary and (arr[i].get("kind", "") == "" or BUILDINGS.has(arr[i].kind)):
			slots[i] = {"kind": str(arr[i].get("kind", "")), "stored": int(arr[i].get("stored", 0)), "progress": float(arr[i].get("progress", 0.0)),
				"level": clampi(int(arr[i].get("level", 1)), 1, TURRET_LEVELS.size())}
		else:
			slots[i] = _empty_slot()
	changed.emit()
