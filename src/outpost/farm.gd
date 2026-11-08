class_name Farm
extends RefCounted
## Quinta do posto (regras puras): talhões vazio → a crescer → pronto. Plantar paga a
## semente; colher dá YIELD unidades da cultura. As culturas lentas valem mais.

signal changed

const PLOTS := 4
const YIELD := 3
## cultura -> {time (s), seed (¢), resource (tipo na carteira)}
const CROPS := {
	"fast": {"time": 120.0, "seed": 2, "resource": Wallet.CROP_FAST},
	"mid": {"time": 240.0, "seed": 4, "resource": Wallet.CROP_MID},
	"slow": {"time": 420.0, "seed": 8, "resource": Wallet.CROP_SLOW},
}
const ORDER := ["fast", "mid", "slow"]

## {crop: "" ou cultura, t: segundos a crescer}
var plots: Array[Dictionary] = []
## Multiplicador da velocidade de crescimento (vantagem da Barbara, #35).
var growth_speed := 1.0

func _init() -> void:
	for i in PLOTS:
		plots.append({"crop": "", "t": 0.0})

func state(i: int) -> String:
	var p: Dictionary = plots[i]
	if p.crop == "":
		return "empty"
	return "ready" if float(p.t) >= float(CROPS[p.crop].time) else "growing"

## 0..1 do crescimento.
func progress(i: int) -> float:
	var p: Dictionary = plots[i]
	if p.crop == "":
		return 0.0
	return clampf(float(p.t) / float(CROPS[p.crop].time), 0.0, 1.0)

func remaining(i: int) -> float:
	var p: Dictionary = plots[i]
	if p.crop == "":
		return 0.0
	return maxf(float(CROPS[p.crop].time) - float(p.t), 0.0) / growth_speed

func plant(i: int, crop: String, wallet: Wallet) -> bool:
	if i < 0 or i >= PLOTS or state(i) != "empty" or not CROPS.has(crop):
		return false
	if not wallet.spend({Wallet.CREDITS: int(CROPS[crop].seed)}):
		return false
	plots[i] = {"crop": crop, "t": 0.0}
	changed.emit()
	return true

## Colhe se estiver pronto. Devolve as unidades.
func harvest(i: int, wallet: Wallet) -> int:
	if state(i) != "ready":
		return 0
	wallet.add(CROPS[plots[i].crop].resource, YIELD)
	plots[i] = {"crop": "", "t": 0.0}
	changed.emit()
	return YIELD

func tick(delta: float) -> void:
	var any := false
	for i in PLOTS:
		if state(i) == "growing":
			var before := state(i)
			plots[i].t = float(plots[i].t) + delta * growth_speed
			if state(i) != before:
				any = true
	if any:
		changed.emit()

func to_dict() -> Dictionary:
	return {"plots": plots.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	var arr: Array = d.get("plots", [])
	for i in PLOTS:
		if i < arr.size() and arr[i] is Dictionary and (str(arr[i].get("crop", "")) == "" or CROPS.has(arr[i].crop)):
			plots[i] = {"crop": str(arr[i].get("crop", "")), "t": float(arr[i].get("t", 0.0))}
		else:
			plots[i] = {"crop": "", "t": 0.0}
	changed.emit()
