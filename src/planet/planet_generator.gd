class_name PlanetGenerator
extends RefCounted
## Gera um PlanetData determinístico a partir de uma seed. Não cria nós.

const DEFAULT_RADIUS := 60.0
const POST_COUNT := 3
const POST_CLEAR_M := 9.0 # raio aplanado e sem decoração à volta de cada posto
const OUTPOST_CLEAR_M := 14.0
const LAIR_CLEAR_M := 10.0
const MAX_SLOPE_DEG := 28.0

## Biomas: lista de tipos de decoração (repetir um tipo em `kinds` aumenta o seu peso). count = quantos tentar colocar num planeta de raio 60
## (escala com a área); size = altura em m [min, max]; clear = raio livre em m.
const BIOMES := {
	"prado": {
		"ground": Color("8fd3a0"),
		"height_amp": 1.8,
		"noise_freq": 0.03,
		"props": [
			{"kinds": ["natureza/Tree_Blob_1", "natureza/Tree_Blob_2", "natureza/Tree_Blob_3", "natureza/Tree_Blob_3", "natureza/Tree_Blob_3"], "count": 95, "size": [3.2, 4.6], "clear": 2.2, "outline": true, "collider": 0.11},
			{"kinds": ["natureza/Bush_1", "natureza/Bush_2", "natureza/Bush_3", "natureza/Bush_3", "natureza/Bush_3"], "count": 130, "size": [0.7, 1.2], "clear": 1.0, "outline": true},
			{"kinds": ["natureza/Rock_Large_1", "natureza/Rock_Large_2", "natureza/Rock_Large_3"], "count": 40, "size": [1.2, 2.2], "clear": 1.8, "outline": true, "collider": 0.45},
			{"kinds": ["natureza/Rock_1", "natureza/Rock_2", "natureza/Rock_3", "natureza/Rock_4"], "count": 50, "size": [0.35, 0.7], "clear": 0.6, "outline": true},
			{"kinds": ["natureza/Plant_1", "natureza/Plant_2", "natureza/Plant_2", "natureza/Plant_1", "natureza/Plant_3"], "count": 80, "size": [0.5, 0.9], "clear": 0.6, "outline": true},
			{"kinds": ["natureza/Grass_1", "natureza/Grass_2", "natureza/Grass_3"], "count": 450, "size": [0.25, 0.45], "clear": 0.3, "outline": false},
		],
	},
}

static func generate(p_seed: int, biome := "prado", radius := DEFAULT_RADIUS) -> PlanetData:
	var b: Dictionary = BIOMES[biome]
	var d := PlanetData.new()
	d.seed = p_seed
	d.biome = biome
	d.radius = radius
	d.height_amp = b.height_amp
	d.noise = FastNoiseLite.new()
	d.noise.seed = p_seed
	d.noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	d.noise.frequency = b.noise_freq
	d.noise.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p_seed)
	var spin := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))

	_place_spots(d, rng, spin)
	_place_props(d, b, rng, spin)
	return d

## Postos o mais afastados possível (farthest point sampling), depois o posto avançado
## longe dos postos e o covil do lado oposto ao posto avançado.
static func _place_spots(d: PlanetData, rng: RandomNumberGenerator, spin: Basis) -> void:
	var cands := fibonacci_dirs(600, spin)
	cands = cands.filter(func(c: Vector3) -> bool: return d.slope_deg(c) < MAX_SLOPE_DEG * 0.6)
	d.posts.append(cands[rng.randi() % cands.size()])
	while d.posts.size() < POST_COUNT:
		d.posts.append(_farthest(cands, d.posts))
	d.outpost_dir = _farthest(cands, d.posts)
	d.lair_dir = _farthest(cands, d.posts + [d.outpost_dir])
	# Aplanar à altura do terreno original no centro de cada zona.
	for p in d.posts:
		d.flat_spots.append({"dir": p, "angle": POST_CLEAR_M / d.radius, "h": d.height_at(p)})
	d.flat_spots.append({"dir": d.outpost_dir, "angle": OUTPOST_CLEAR_M / d.radius, "h": d.height_at(d.outpost_dir)})
	d.flat_spots.append({"dir": d.lair_dir, "angle": LAIR_CLEAR_M / d.radius, "h": d.height_at(d.lair_dir)})

## Dentro (ou a tocar) uma zona aplanada (postos, posto avançado, covil)?
static func _in_spot(d: PlanetData, dir: Vector3, clear: float) -> bool:
	for s in d.flat_spots:
		if d.arc_m(dir, s.dir) < s.angle * d.radius + clear:
			return true
	return false

static func _farthest(cands: Array, chosen: Array) -> Vector3:
	var best := Vector3.ZERO
	var best_d := -1.0
	for c: Vector3 in cands:
		var m := INF
		for s: Vector3 in chosen:
			m = minf(m, c.angle_to(s))
		if m > best_d:
			best_d = m
			best = c
	return best

static func _place_props(d: PlanetData, b: Dictionary, rng: RandomNumberGenerator, spin: Basis) -> void:
	var area_k := pow(d.radius / DEFAULT_RADIUS, 2.0)
	var grid := _Grid.new(d.radius)
	for group: Dictionary in b.props:
		var wanted := int(round(group.count * area_k))
		# Candidatos: espiral de Fibonacci com rotação própria por grupo, embaralhados.
		var group_spin := spin * Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0))
		var cands := fibonacci_dirs(wanted * 4, group_spin)
		_shuffle(cands, rng)
		var placed := 0
		for c: Vector3 in cands:
			if placed >= wanted:
				break
			var clear: float = group.clear
			if _in_spot(d, c, clear) or grid.blocked(c, clear):
				continue
			if d.slope_deg(c) > MAX_SLOPE_DEG:
				continue
			var kinds: Array = group.kinds
			d.placements.append({
				"kind": kinds[rng.randi() % kinds.size()],
				"dir": c,
				"yaw": rng.randf() * TAU,
				"size": rng.randf_range(group.size[0], group.size[1]),
				"clear": clear,
				"outline": group.outline,
				"collider": group.get("collider", 0.0),
			})
			grid.add(c, clear)
			placed += 1

## `n` direções quase uniformes na esfera (espiral de Fibonacci), rodadas por `spin`.
static func fibonacci_dirs(n: int, spin := Basis.IDENTITY) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var golden := PI * (3.0 - sqrt(5.0))
	for i in n:
		var y := 1.0 - (i + 0.5) / n * 2.0
		var r := sqrt(1.0 - y * y)
		var t := golden * i
		out.append((spin * Vector3(cos(t) * r, y, sin(t) * r)).normalized())
	return out

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t

## Grelha espacial para testar sobreposições da decoração depressa.
## Assume raios livres <= MAX_CLEAR (as zonas grandes são testadas à parte em _in_spot).
class _Grid:
	const MAX_CLEAR := 2.5
	var cell := 5.0
	var r: float
	var cells := {}
	func _init(radius: float) -> void:
		r = radius
	func _key(p: Vector3) -> Vector3i:
		return Vector3i((p / cell).floor())
	func add(dir: Vector3, clear: float) -> void:
		var p := dir * r
		var k := _key(p)
		if not cells.has(k):
			cells[k] = []
		cells[k].append([p, clear])
	func blocked(dir: Vector3, clear: float) -> bool:
		var p := dir * r
		var k := _key(p)
		var reach := int(ceil((clear + MAX_CLEAR) / cell))
		for x in range(-reach, reach + 1):
			for y in range(-reach, reach + 1):
				for z in range(-reach, reach + 1):
					var kk := k + Vector3i(x, y, z)
					if not cells.has(kk):
						continue
					for e in cells[kk]:
						if p.distance_to(e[0]) < clear + e[1]:
							return true
		return false
