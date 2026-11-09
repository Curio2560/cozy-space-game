class_name Galaxy
extends RefCounted
## Caminho na galáxia (regras puras, F5 #49/#50): Prado → Ácido → Lava fixos; depois disso,
## em cada partida escolhe-se entre 2 planetas aleatórios (deterministas pela semente da
## galáxia). Só para a frente. Cada planeta conta como +2 noites de dificuldade.

const FIXED := ["prado", "acido", "lava"]
const NIGHTS_PER_PLANET := 2

var seed_value := 1
var index := 0 # planeta atual (0 = o primeiro)

## Planetas possíveis a seguir ao atual: [{biome, seed}] (1 no caminho fixo, 2 depois).
func next_options() -> Array:
	var i := index + 1
	if i < FIXED.size():
		return [{"biome": FIXED[i], "seed": planet_seed(i, 0)}]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value * 977 + i * 31)
	var biomes: Array = FIXED.duplicate()
	var a: String = biomes[rng.randi() % biomes.size()]
	biomes.erase(a)
	var b: String = biomes[rng.randi() % biomes.size()]
	return [{"biome": a, "seed": planet_seed(i, 0)}, {"biome": b, "seed": planet_seed(i, 1)}]

func planet_seed(i: int, option: int) -> int:
	return absi(hash(seed_value * 7919 + i * 104729 + option * 13)) % 100000

## Primeiro planeta.
func first() -> Dictionary:
	return {"biome": FIXED[0], "seed": planet_seed(0, 0)}

## Avança para a opção escolhida. Devolve-a.
func advance(option: Dictionary) -> Dictionary:
	index += 1
	return option

## Noites a somar à dificuldade das vagas no planeta atual.
func night_offset() -> int:
	return NIGHTS_PER_PLANET * index

func to_dict() -> Dictionary:
	return {"seed": seed_value, "index": index}

func from_dict(d: Dictionary) -> void:
	seed_value = int(d.get("seed", 1))
	index = maxi(int(d.get("index", 0)), 0)
