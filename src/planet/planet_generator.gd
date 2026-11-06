class_name PlanetGenerator
extends RefCounted
## Gera um PlanetData determinístico a partir de uma seed. Não cria nós.

const DEFAULT_RADIUS := 60.0
const POST_COUNT := 3
const POST_CLEAR_M := 9.0 # raio aplanado e sem decoração à volta de cada posto
const OUTPOST_CLEAR_M := 14.0
const LAIR_CLEAR_M := 10.0
const MAX_SLOPE_DEG := 28.0

## Biomas: lista de tipos de decoração (repetir um tipo em `kinds` aumenta o seu peso).
## kit_tint: tom multiplicado nos modelos do kit (que têm a paleta numa textura).
## pile: [min, max] — em vez de espalhar, faz montes: escolhe centros e põe entre min e max
## objetos a menos de `pile_radius` m de cada centro (aglomerados de pedras).
## cluster (0..1): quanto a decoração se junta em manchas (bosques e clareiras) em vez de
## se espalhar por igual. count = quantos tentar colocar num planeta de raio 60
## (escala com a área); size = altura em m [min, max]; clear = raio livre em m.
const BIOMES := {
	"prado": {
		"ground": Color("8fd3a0"),
		"height_amp": 1.8,
		"noise_freq": 0.03,
		# Cores do pack de natureza por nome de material (as árvores do kit usam a paleta própria).
		"palette": {
			"Green": Color("6cc47f"), "DarkGreen": Color("3f9c6e"), "Leaves": Color("6cc47f"),
			"Wood": Color("a8735a"), "LightWood": Color("c99a74"), "White": Color("efe9dc"),
			"Black": Color("3a3346"), "Orange": Color("ff9f5a"), "LightOrange": Color("ffc07a"),
			"Berry": Color("e8546e"), "Pink": Color("ff9ecf"), "Snow": Color("f4f8ff"),
			"Grass": Color("5fb873"), "Rock": Color("c4bccf"),
		},
		"props": [
			{"kinds": ["nature/BirchTree_1", "nature/BirchTree_2", "nature/BirchTree_3", "nature/BirchTree_4", "nature/BirchTree_5",
				"nature/BirchTree_Autumn_1", "nature/CommonTree_Autumn_3", "natureza/Tree_Blob_3"],
				"count": 300, "size": [3.4, 5.2], "clear": 2.0, "outline": true, "collider": 0.06, "cluster": 0.55},
			{"kinds": ["nature/Bush_1", "nature/Bush_2", "nature/BushBerries_1", "nature/BushBerries_2", "natureza/Bush_3"],
				"count": 260, "size": [0.7, 1.2], "clear": 1.0, "outline": true, "cluster": 0.4},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 20, "size": [2.2, 4.5], "clear": 2.2, "outline": true, "collider": 0.4, "cluster": 0.3},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 70, "size": [0.6, 1.8], "clear": 1.0, "outline": true},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 180, "size": [0.25, 1.1], "clear": 0.45, "outline": true, "pile": [3, 7], "pile_radius": 2.6},
			{"kinds": ["natureza/Plant_1", "natureza/Plant_2", "natureza/Plant_2", "natureza/Plant_1", "natureza/Plant_3"], "count": 120, "size": [0.5, 0.9], "clear": 0.6, "outline": true, "cluster": 0.3},
			{"kinds": ["mdvl/mdvl_nature_grass_01", "mdvl/mdvl_nature_grass_01", "natureza/Grass_2"], "count": 1500, "size": [0.3, 0.65], "clear": 0.22, "outline": false, "cluster": 0.3},
		],
	},
	"acido": {
		"ground": Color("8a7bb8"),
		"sky": {"bg": Color("1e2a2a"), "ambient": Color("c4cfc8"), "sun": Color("f4ffe8")},
		"kit_tint": Color("cdbcff"),
		"height_amp": 2.2,
		"noise_freq": 0.035,
		"palette": {
			"Green": Color("b6e83a"), "DarkGreen": Color("78b02c"), "Leaves": Color("b6e83a"),
			"Wood": Color("5d4a78"), "LightWood": Color("7a64a0"), "White": Color("d6e8c4"),
			"Black": Color("2c2438"), "Orange": Color("e8e44a"), "LightOrange": Color("cdf27a"),
			"Berry": Color("c44ae6"), "Pink": Color("e07af0"), "Snow": Color("e8ffd0"),
			"Grass": Color("a6d64a"), "Rock": Color("5c4c80"),
		},
		"props": [
			{"kinds": ["nature/CommonTree_Dead_1", "nature/CommonTree_Dead_2", "nature/CommonTree_Dead_3", "nature/CommonTree_Dead_4", "nature/CommonTree_Dead_5",
				"nature/BirchTree_Dead_1", "nature/BirchTree_Dead_3", "natureza/Tree_Spikes_2"],
				"count": 240, "size": [3.0, 4.8], "clear": 2.0, "outline": true, "collider": 0.06, "cluster": 0.5},
			{"kinds": ["nature/Bush_1", "nature/Bush_2", "nature/BushBerries_1", "natureza/Tree_Spiral_1"],
				"count": 220, "size": [0.7, 1.4], "clear": 1.0, "outline": true},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 30, "size": [2.2, 4.5], "clear": 2.2, "outline": true, "collider": 0.4, "cluster": 0.3},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 90, "size": [0.6, 1.8], "clear": 1.0, "outline": true},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 220, "size": [0.25, 1.1], "clear": 0.45, "outline": true, "pile": [3, 7], "pile_radius": 2.6},
			{"kinds": ["mdvl/mdvl_nature_grass_01"], "count": 1200, "size": [0.3, 0.65], "clear": 0.22, "outline": false, "cluster": 0.3},
		],
	},
	"lava": {
		"ground": Color("6e4a4e"),
		"sky": {"bg": Color("2e1418"), "ambient": Color("d2c2c8"), "sun": Color("ffe6cc")},
		"kit_tint": Color("ffb49c"),
		"height_amp": 2.6,
		"noise_freq": 0.04,
		"palette": {
			"Green": Color("e8743a"), "DarkGreen": Color("b84a32"), "Leaves": Color("e8743a"),
			"Wood": Color("3a2a30"), "LightWood": Color("5a3e40"), "White": Color("8a6e6a"),
			"Black": Color("1e1418"), "Orange": Color("ffc04a"), "LightOrange": Color("ffd27a"),
			"Berry": Color("ffe04a"), "Pink": Color("ff7a4a"), "Snow": Color("c8a8a0"),
			"Grass": Color("b0604a"), "Rock": Color("b8968c"),
		},
		"props": [
			{"kinds": ["nature/Cactus_1", "nature/Cactus_2", "nature/Cactus_3", "nature/Cactus_4", "nature/Cactus_5", "nature/CactusFlower_1", "nature/CactusFlowers_2"],
				"count": 220, "size": [1.2, 3.0], "clear": 1.2, "outline": true, "collider": 0.12, "cluster": 0.45},
			{"kinds": ["nature/CommonTree_Dead_2", "nature/BirchTree_Dead_2", "natureza/Tree_Lava_1", "natureza/Tree_Lava_2", "natureza/Tree_Lava_3"],
				"count": 90, "size": [3.0, 4.5], "clear": 2.0, "outline": true, "collider": 0.06},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 45, "size": [2.2, 4.5], "clear": 2.2, "outline": true, "collider": 0.4, "cluster": 0.3},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 120, "size": [0.6, 1.8], "clear": 1.0, "outline": true},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 280, "size": [0.25, 1.1], "clear": 0.45, "outline": true, "pile": [3, 7], "pile_radius": 2.6},
			{"kinds": ["mdvl/mdvl_nature_grass_01"], "count": 500, "size": [0.25, 0.5], "clear": 0.22, "outline": false, "cluster": 0.55},
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
	var gi := 0
	for group: Dictionary in b.props:
		gi += 1
		var wanted := int(round(group.count * area_k))
		var cluster: float = group.get("cluster", 0.0)
		var patches := FastNoiseLite.new()
		patches.seed = d.seed * 31 + gi
		patches.frequency = 0.045
		patches.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		# Candidatos: espiral de Fibonacci com rotação própria por grupo, embaralhados.
		var group_spin := spin * Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0))
		var cands := fibonacci_dirs(int(wanted * (4.0 + cluster * 6.0)), group_spin)
		_shuffle(cands, rng)
		if group.has("pile"):
			cands = _pile_candidates(cands, group, wanted, d.radius, rng)
		var placed := 0
		for c: Vector3 in cands:
			if placed >= wanted:
				break
			var clear: float = group.clear
			if _in_spot(d, c, clear) or grid.blocked(c, clear):
				continue
			if d.slope_deg(c) > MAX_SLOPE_DEG:
				continue
			if cluster > 0.0:
				# Manchas: aceitar mais onde o ruído é alto; nas clareiras quase nada.
				var n := patches.get_noise_3dv(c * d.radius)
				var keep := lerpf(1.0, smoothstep(-0.25, 0.35, n), cluster)
				if rng.randf() > keep:
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

## Candidatos em montes: para cada centro, várias direções a menos de pile_radius metros.
static func _pile_candidates(centers: Array[Vector3], group: Dictionary, wanted: int, radius: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var lo: int = group.pile[0]
	var hi: int = group.pile[1]
	var r_ang: float = group.pile_radius / radius
	for c in centers:
		if out.size() >= wanted * 3:
			break
		var n := rng.randi_range(lo, hi) * 3 # sobram candidatos para os rejeitados
		var t1 := c.cross(Vector3.UP if absf(c.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := c.cross(t1)
		for i in n:
			var a := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * r_ang
			out.append((c + (t1 * cos(a) + t2 * sin(a)) * rr).normalized())
	return out

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
