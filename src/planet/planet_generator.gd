class_name PlanetGenerator
extends RefCounted
## Gera um PlanetData determinístico a partir de uma seed. Não cria nós.

const DEFAULT_RADIUS := 60.0
const POST_COUNT := 3
const POST_CLEAR_M := 10.0 # raio aplanado e sem decoração à volta de cada posto
const OUTPOST_CLEAR_M := 27.0 # base + praça + anel de slots do posto (#32)
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
		"dirt": 70,
		"ground": Color("8fd3a0"),
		"turf": {"density": 3.4, "size": [0.42, 0.9]},
		"creatures": 16,
		"sky": {"bg": Color("2b2146"), "ambient": Color("b9a8e8"), "sun": Color("fff1dc"),
			"nebula_a": Color("5b3f94"), "nebula_b": Color("ff9f7a"),
			"planets": [
				{"tex": "planeta_ciano", "dir": Vector3(0.45, 0.6, -0.66), "size": 13.0},
				{"tex": "planeta_rosa", "dir": Vector3(-0.72, 0.35, 0.6), "size": 6.0, "fps": 1.0},
				{"tex": "planeta_vermelho", "dir": Vector3(0.1, -0.55, 0.83), "size": 3.0, "fps": 2.0},
			]},
		"height_amp": 1.8,
		"noise_freq": 0.03,
		# Cores do pack de natureza por nome de material (as árvores do kit usam a paleta própria).
		"palette": {
			"Green": Color("6cc47f"), "DarkGreen": Color("3f9c6e"), "Leaves": Color("6cc47f"),
			"Wood": Color("a8735a"), "LightWood": Color("c99a74"), "White": Color("efe9dc"),
			"Black": Color("3a3346"), "Orange": Color("ff9f5a"), "LightOrange": Color("ffc07a"),
			"Berry": Color("e8546e"), "Pink": Color("ff9ecf"), "Snow": Color("f4f8ff"),
			"Grass": Color("5fb873"), "Rock": Color("c4bccf"), "Road": Color("b88a62"),
		},
		"props": [
			{"kinds": ["nature/BirchTree_1", "nature/BirchTree_2", "nature/BirchTree_3", "nature/BirchTree_4", "nature/BirchTree_5",
				"nature/BirchTree_Autumn_1", "nature/CommonTree_Autumn_3", "natureza/Tree_Blob_3"],
				"count": 380, "size": [3.4, 5.2], "clear": 2.0, "outline": true, "collider": 0.06, "cluster": 0.55},
			{"kinds": ["nature/Bush_1", "nature/Bush_2", "nature/BushBerries_1", "nature/BushBerries_2", "natureza/Bush_3"],
				"count": 380, "size": [0.7, 1.2], "clear": 1.0, "outline": false, "cluster": 0.4},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 20, "size": [2.2, 4.5], "clear": 2.2, "outline": true, "collider": 0.4, "cluster": 0.3},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 70, "size": [0.6, 1.8], "clear": 1.0, "outline": true},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 180, "size": [0.25, 1.1], "clear": 0.45, "outline": true, "pile": [3, 7], "pile_radius": 2.6},
			{"kinds": ["natureza/Plant_1", "natureza/Plant_2", "natureza/Plant_2", "natureza/Plant_1", "natureza/Plant_3"], "count": 180, "size": [0.5, 0.9], "clear": 0.6, "outline": true, "cluster": 0.3},
			{"kinds": ["mdvl/mdvl_nature_grass_01", "mdvl/mdvl_nature_grass_01", "natureza/Grass_2"], "count": 250, "size": [0.3, 0.65], "clear": 0.22, "outline": false, "cluster": 0.3},
		],
	},
	"acido": {
		"dirt": 60,
		"ground": Color("8a7bb8"),
		"turf": {"density": 2.8, "size": [0.35, 0.75]},
		"ground_grass": 0.6,
		"creatures": 20,
		"sky": {"bg": Color("142220"), "ambient": Color("c4cfc8"), "sun": Color("f4ffe8"),
			"nebula_a": Color("2c6e40"), "nebula_b": Color("8a4ac6"),
			"planets": [
				{"tex": "planeta_verde", "dir": Vector3(-0.3, 0.7, -0.65), "size": 15.0},
				{"tex": "planeta_verde_azul", "dir": Vector3(0.75, 0.2, 0.62), "size": 7.0, "fps": 1.2},
			]},
		"kit_tint": Color("cdbcff"),
		"o2_drain": 1.0, # O₂ por segundo a pé (100 = cheio)
		"rivers": {"count": 9, "width": [2.2, 3.2], "length": [70.0, 150.0], "o2_near": 1.0,
			"color": Color("8cff3a"), "wiggle": 9.0, "from_reliefs": true},
		"o2_bubbles": 26,
		"height_amp": 2.2,
		"noise_freq": 0.035,
		"palette": {
			"Green": Color("b6e83a"), "DarkGreen": Color("78b02c"), "Leaves": Color("b6e83a"),
			"Wood": Color("5d4a78"), "LightWood": Color("7a64a0"), "White": Color("d6e8c4"),
			"Black": Color("2c2438"), "Orange": Color("e8e44a"), "LightOrange": Color("cdf27a"),
			"Berry": Color("c44ae6"), "Pink": Color("e07af0"), "Snow": Color("e8ffd0"),
			"Grass": Color("a6d64a"), "Rock": Color("5c4c80"), "Road": Color("5a4c78"),
		},
		"props": [
			{"kinds": ["nature/CommonTree_Dead_1", "nature/CommonTree_Dead_2", "nature/CommonTree_Dead_3", "nature/CommonTree_Dead_4", "nature/CommonTree_Dead_5",
				"nature/BirchTree_Dead_1", "nature/BirchTree_Dead_3", "natureza/Tree_Spikes_2"],
				"count": 360, "size": [3.0, 4.8], "clear": 2.0, "outline": true, "collider": 0.06, "cluster": 0.5},
			{"kinds": ["nature/Bush_1", "nature/Bush_2", "nature/BushBerries_1", "natureza/Tree_Spiral_1"],
				"count": 320, "size": [0.7, 1.4], "clear": 1.0, "outline": true},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 30, "size": [2.2, 4.5], "clear": 2.2, "outline": true, "collider": 0.4, "cluster": 0.3},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 90, "size": [0.6, 1.8], "clear": 1.0, "outline": true},
			{"kinds": ["rocks/SM_Rocks_01", "rocks/SM_Rocks_02", "rocks/SM_Rocks_03", "rocks/SM_Rocks_04", "rocks/SM_Rocks_05", "rocks/SM_Rocks_06", "rocks/SM_Rocks_07", "rocks/SM_Rocks_08", "rocks/SM_Rocks_09", "rocks/SM_Rocks_10", "rocks/SM_Rocks_11"], "count": 220, "size": [0.25, 1.1], "clear": 0.45, "outline": true, "pile": [3, 7], "pile_radius": 2.6},
			{"kinds": ["mdvl/mdvl_nature_grass_01"], "count": 300, "size": [0.3, 0.65], "clear": 0.22, "outline": false, "cluster": 0.3},
		],
	},
	"lava": {
		"dirt": 90,
		"ground": Color("6e4a4e"),
		"turf": {"density": 0.6, "size": [0.25, 0.45]},
		"ground_grass": 0.25,
		"creatures": 20,
		"sky": {"bg": Color("2a0e14"), "ambient": Color("d2c2c8"), "sun": Color("ffe6cc"),
			"nebula_a": Color("7a2034"), "nebula_b": Color("ff8a3a"),
			"planets": [
				{"tex": "planeta_vermelho", "dir": Vector3(0.5, 0.55, -0.67), "size": 17.0, "fps": 1.0},
				{"tex": "planeta_rosa", "dir": Vector3(-0.6, 0.45, 0.66), "size": 5.0, "fps": 1.8},
			]},
		"kit_tint": Color("ffb49c"),
		# Fissuras de lava: curtas e estreitas; queimam a pé e aquecem o rover (#21).
		"rivers": {"count": 16, "width": [1.2, 2.0], "length": [14.0, 38.0], "o2_near": 0.0,
			"color": Color("ff7a1a"), "wiggle": 3.0, "spacing": 4.0},
		"rover_heat": true,
		"height_amp": 2.6,
		"noise_freq": 0.04,
		"palette": {
			"Green": Color("e8743a"), "DarkGreen": Color("b84a32"), "Leaves": Color("e8743a"),
			"Wood": Color("3a2a30"), "LightWood": Color("5a3e40"), "White": Color("8a6e6a"),
			"Black": Color("1e1418"), "Orange": Color("ffc04a"), "LightOrange": Color("ffd27a"),
			"Berry": Color("ffe04a"), "Pink": Color("ff7a4a"), "Snow": Color("c8a8a0"),
			"Grass": Color("b0604a"), "Rock": Color("b8968c"), "Road": Color("3e2e32"),
		},
		"props": [
			{"kinds": ["nature/Cactus_1", "nature/Cactus_2", "nature/Cactus_3", "nature/Cactus_4", "nature/Cactus_5", "nature/CactusFlower_1", "nature/CactusFlowers_2"],
				"count": 300, "size": [1.2, 3.0], "clear": 1.2, "outline": true, "collider": 0.12, "cluster": 0.45},
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
	_place_roads(d, rng)
	_place_reliefs(d, p_seed)
	_place_rivers(d, b, p_seed) # depois do relevo: os rios do ácido nascem nas montanhas
	_place_dirt(d, b, rng)
	_place_props(d, b, rng, spin)
	_place_obstacles(d)
	_place_turf(d, b, p_seed)
	_place_o2_bubbles(d, b, p_seed)
	return d

const RIVER_TRIES := 600
const RIVER_WIGGLE_M := 9.0 # por omissão; cada bioma pode dar "wiggle"
const BRIDGE_MARGIN := 1 # pontos da estrada a mais de cada lado do rio

## Rios de ácido (biomas com "rivers"): caminhos estreitos e sinuosos longe das zonas
## aplanadas, que cruzam as estradas (com pontes) mas não correm ao longo delas.
static func _place_rivers(d: PlanetData, b: Dictionary, p_seed: int) -> void:
	var cfg: Dictionary = b.get("rivers", {})
	if cfg.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p_seed * 389 + 17)
	var wanted := int(round(float(cfg.count) * pow(d.radius / DEFAULT_RADIUS, 2.0)))
	var tries := 0
	while d.rivers.size() < wanted and tries < RIVER_TRIES:
		tries += 1
		var width := rng.randf_range(cfg.width[0], cfg.width[1])
		var a := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var toward := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if cfg.get("from_reliefs", false) and not d.reliefs.is_empty():
			# Nasce no sopé de uma montanha e corre para longe dela.
			var r: Dictionary = d.reliefs[(tries + d.rivers.size()) % d.reliefs.size()]
			var foot: float = ReliefKit.piece(r.kind).radius * float(r.scale)
			var bearing: Vector3 = SphereMath.basis_from_up(r.dir, rng.randf() * TAU).z
			a = d.toward_point(r.dir, (r.dir + bearing * 0.1).normalized(), foot * 0.75)
			toward = d.toward_point(r.dir, (r.dir + bearing * 0.1).normalized(), foot + 80.0)
		var bb := d.toward_point(a, toward, rng.randf_range(cfg.length[0], cfg.length[1]))
		var path := _smooth(road_path(d, a, bb, rng, float(cfg.get("wiggle", RIVER_WIGGLE_M))), 2)
		if _river_ok(d, path, width, float(cfg.get("spacing", 6.0))):
			d.add_river(path, width)
	_place_bridges(d)

static func _river_ok(d: PlanetData, path: PackedVector3Array, width: float, spacing: float) -> bool:
	var near_road := 0
	for i in path.size():
		var p := path[i]
		if i > 3 and d.in_relief(p):
			return false # não sobe para cima de (outra) montanha
		for s in d.flat_spots:
			if d.arc_m(p, s.dir) < s.angle * d.radius + width + 3.0:
				return false
		if d.river_clearance(p) < width + spacing:
			return false # longe dos outros rios
		if d.road_clearance(p) < width * 0.5 + 1.0:
			near_road += 1
	# Cruzar uma estrada gasta poucos pontos; correr ao lado dela gasta muitos.
	return near_road <= maxi(3, int(path.size() * 0.12))

## Uma ponte em cada sítio onde uma estrada passa por cima de um rio.
static func _place_bridges(d: PlanetData) -> void:
	for road in d.roads:
		var pts: PackedVector3Array = road.points
		var i := 0
		while i < pts.size():
			if d.river_clearance(pts[i]) >= 0.8:
				i += 1
				continue
			var j := i
			while j + 1 < pts.size() and d.river_clearance(pts[j + 1]) < 0.8:
				j += 1
			var from := maxi(0, i - BRIDGE_MARGIN)
			var to := mini(pts.size() - 1, j + BRIDGE_MARGIN)
			d.add_bridge(pts.slice(from, to + 1), float(road.width) + 0.8)
			i = j + 1

## Bolhas de O₂: a maioria junto aos rios (onde se gasta mais), algumas espalhadas.
static func _place_o2_bubbles(d: PlanetData, b: Dictionary, p_seed: int) -> void:
	var n := int(round(float(b.get("o2_bubbles", 0)) * pow(d.radius / DEFAULT_RADIUS, 2.0)))
	if n == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p_seed * 151 + 3)
	var tries := 0
	while d.o2_bubbles.size() < n and tries < n * 30:
		tries += 1
		var dir: Vector3
		if rng.randf() < 0.7 and not d.rivers.is_empty():
			var river: Dictionary = d.rivers[rng.randi() % d.rivers.size()]
			var pts: PackedVector3Array = river.points
			var p := pts[rng.randi() % pts.size()]
			var side := SphereMath.basis_from_up(p, rng.randf() * TAU).z
			dir = (p + side * tan((float(river.width) * 0.5 + rng.randf_range(1.5, 5.0)) / d.radius)).normalized()
		else:
			dir = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if d.in_acid(dir) or d.river_clearance(dir) < 1.0 or d.in_relief(dir) or _in_spot(d, dir, 0.0):
			continue
		var close := false
		for o in d.o2_bubbles:
			if d.arc_m(o, dir) < 8.0:
				close = true
				break
		if not close:
			d.o2_bubbles.append(dir)

## Peças de relevo por planeta (raio 60; escala com a área). Largas e suaves: cabem poucas.
const RELIEF_COUNT := [6, 9]
const RELIEF_MIN_HEIGHT := 2.5 # m; mais baixas quase não se viam
const RELIEF_TRIES := 1200
const MAX_RELIEF_SLOPE_DEG := 26.0

## Penhascos, colinas e montanhas do terreno modular: longe das zonas aplanadas, das estradas
## e umas das outras. RNG próprio para não mudar o resto do planeta.
static func _place_reliefs(d: PlanetData, p_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p_seed * 613 + 29)
	var area_k := pow(d.radius / DEFAULT_RADIUS, 2.0)
	var wanted := int(round(rng.randi_range(RELIEF_COUNT[0], RELIEF_COUNT[1]) * area_k))
	var tries := 0
	while d.reliefs.size() < wanted and tries < RELIEF_TRIES:
		tries += 1
		var kind: String = ReliefKit.KINDS[rng.randi() % ReliefKit.KINDS.size()]
		var pc := ReliefKit.piece(kind)
		# Largas: esticadas na horizontal; as grandes encolhem nos planetas pequenos e quando
		# já falhou muita coisa.
		var fit := minf(1.0, d.radius * 0.5 / float(pc.radius))
		var scale := rng.randf_range(1.7, 2.3) * fit * lerpf(1.0, 0.6, float(tries) / RELIEF_TRIES)
		# Altura limitada para nenhuma encosta passar de MAX_RELIEF_SLOPE_DEG (o rover sobe).
		var max_h := scale * tan(deg_to_rad(MAX_RELIEF_SLOPE_DEG)) / maxf(float(pc.grad), 0.01)
		var hscale := minf(scale * rng.randf_range(1.0, 1.4), max_h)
		if float(pc.top) * hscale < RELIEF_MIN_HEIGHT:
			continue
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var foot: float = pc.radius * scale
		if not _relief_fits(d, dir, foot):
			continue
		var yaw := rng.randf() * TAU
		var r := {"dir": dir, "basis": SphereMath.basis_from_up(dir, yaw), "scale": scale}
		if not _relief_clear_of_roads(d, r, pc):
			continue
		d.add_relief(kind, dir, yaw, scale, hscale)

static func _relief_fits(d: PlanetData, dir: Vector3, foot: float) -> bool:
	for s in d.flat_spots:
		if d.arc_m(dir, s.dir) < s.angle * d.radius + foot + 3.0:
			return false
	for o in d.reliefs:
		var other := ReliefKit.piece(o.kind)
		if d.arc_m(dir, o.dir) < foot + float(other.radius) * float(o.scale) + 2.0:
			return false
	return true

## Nenhuma estrada passa por cima da peça (amostras de 3 em 3 m sobre a área dela).
static func _relief_clear_of_roads(d: PlanetData, r: Dictionary, pc: Dictionary) -> bool:
	var half: float = pc.half
	var step := 2.5 / float(r.scale)
	var x := -half
	while x <= half:
		var z := -half
		while z <= half:
			if ReliefKit.sample(pc, x, z) >= 0.0 and d.road_clearance(d.relief_dir(r, x, z)) < 1.5:
				return false
			z += step
		x += step
	return true

const MAIN_ROAD_WIDTH := 4.5
const SIDE_ROAD_WIDTH := 2.6
const ROAD_STEP_M := 2.0
const PATH_WIDTH := 2.0
const SIDE_ROADS := 12
const PATHS := 12 # alguns são descartados por correrem colados a outras estradas
const CONNECTORS := 3
## Meia diagonal (m) das estruturas, para as estradas passarem à porta e as contornarem.
const STRUCT_RADIUS := {"post": 3.4, "outpost": 6.8, "lair": 2.4} # casas 4×4 m e base 8×8 m (pack modular)

## Anel dos slots do posto: SLOT_RING_M do centro da base, fora da praça. Dos candidatos à
## volta, ficam os MAX_SLOTS sem estrada (as estradas da praça para os postos passam entre eles).
const SLOT_RINGS_M := [17.0, 22.5]
const SLOT_RADIUS_M := 2.8 # meia diagonal de um edifício de 4×4 m
const SLOT_CANDIDATES := 20
const SLOT_CORRIDOR_DEG := 20.0 # meia largura do corredor livre para cada estrada da praça

static func _place_outpost_slots(d: PlanetData) -> void:
	var ref := SphereMath.basis_from_up(d.outpost_dir).z
	var c := d.outpost_dir
	# Rumos (no plano tangente da base) para cada posto: aí passam as estradas da praça.
	var corridors: Array[Vector3] = []
	for door in d.post_doors:
		corridors.append((door - c * door.dot(c)).normalized())
	var ok: Array[Vector3] = []
	for ring_i in SLOT_RINGS_M.size():
		var ring: float = SLOT_RINGS_M[ring_i]
		for i in SLOT_CANDIDATES:
			if ok.size() >= Outpost.MAX_SLOTS + Farm.PLOTS:
				break
			var a := TAU * (i + 0.5 * ring_i) / SLOT_CANDIDATES # o 2.º anel desfasado
			var t := ref.rotated(c, a)
			var blocked := false
			for cor in corridors:
				if t.angle_to(cor) < deg_to_rad(SLOT_CORRIDOR_DEG):
					blocked = true
			if blocked:
				continue
			var p := d.toward_point(c, (t + c).normalized(), ring)
			for q in ok:
				if d.arc_m(p, q) < SLOT_RADIUS_M * 2.0 + 0.6:
					blocked = true
					break
			if not blocked:
				ok.append(p)
	# Os primeiros para edifícios, os seguintes para os talhões da quinta.
	d.outpost_slots = ok.slice(0, Outpost.MAX_SLOTS)
	d.farm_plots = ok.slice(Outpost.MAX_SLOTS, Outpost.MAX_SLOTS + Farm.PLOTS)

static func _near_slot(d: PlanetData, dir: Vector3, margin: float) -> bool:
	for sl in d.outpost_slots + d.farm_plots:
		if d.arc_m(dir, sl) < SLOT_RADIUS_M + margin:
			return true
	return false

## Estruturas do planeta: [[direção, raio (m)], …].
static func structures(d: PlanetData) -> Array:
	var out := []
	for sl in d.outpost_slots:
		out.append([sl, SLOT_RADIUS_M])
	for fp in d.farm_plots:
		out.append([fp, SLOT_RADIUS_M])
	for p in d.posts:
		out.append([p, STRUCT_RADIUS.post])
	out.append([d.outpost_dir, STRUCT_RADIUS.outpost])
	out.append([d.lair_dir, STRUCT_RADIUS.lair])
	return out

## Rede de estradas (estilo Google Earth: as estradas passam em frente às casas):
## - uma volta principal que passa à porta dos 3 postos;
## - uma praça circular à volta do posto avançado, de onde saem estradas para a porta de cada posto;
## - secundárias que saem das principais (uma até à porta do covil), caminhos que saem das
##   secundárias e ligações entre estradas principais.
## Nenhuma estrada passa por cima de uma estrutura.
static func _place_roads(d: PlanetData, rng: RandomNumberGenerator) -> void:
	var hw := MAIN_ROAD_WIDTH * 0.5
	for p in d.posts:
		d.post_doors.append(d.toward_point(p, d.outpost_dir, STRUCT_RADIUS.post + hw + 1.2))
	# Slots do posto antes das estradas: ficam corredores livres para os postos e as estradas
	# contornam os slots (são estruturas).
	_place_outpost_slots(d)
	# Volta principal pelas portas dos postos.
	for i in d.posts.size():
		var a := d.post_doors[i]
		var b := d.post_doors[(i + 1) % d.posts.size()]
		d.add_road(_road(d, a, b, rng, 7.0, MAIN_ROAD_WIDTH), MAIN_ROAD_WIDTH, true)
	# Praça à volta da base e estradas da praça para cada posto.
	d.plaza_radius_m = STRUCT_RADIUS.outpost + hw + 2.5
	d.add_road(_ring(d, d.outpost_dir, d.plaza_radius_m), MAIN_ROAD_WIDTH, true, true)
	var spokes := 0
	for door in d.post_doors:
		var start := d.toward_point(d.outpost_dir, door, d.plaza_radius_m)
		var spoke := _road(d, start, door, rng, 6.0, MAIN_ROAD_WIDTH)
		# Se correr ao lado da volta principal, sobra: a porta já está ligada pela volta.
		if spokes > 0 and _runs_along_roads(d, spoke, MAIN_ROAD_WIDTH):
			continue
		d.add_road(spoke, MAIN_ROAD_WIDTH, true)
		spokes += 1
	var mains := d.roads.duplicate()
	# Covil: a sua porta fica virada para a estrada principal mais próxima.
	var near := _nearest_road_point(d, d.lair_dir)
	d.lair_door = d.toward_point(d.lair_dir, near, STRUCT_RADIUS.lair + SIDE_ROAD_WIDTH * 0.5 + 1.0)
	d.add_road(_road(d, near, d.lair_door, rng, 4.0, SIDE_ROAD_WIDTH), SIDE_ROAD_WIDTH, false)
	for i in SIDE_ROADS:
		_add_branch(d, mains, rng, 25.0, 70.0, SIDE_ROAD_WIDTH)
	var sides := d.roads.filter(func(r: Dictionary) -> bool: return not r.main)
	for i in PATHS:
		_add_branch(d, sides, rng, 15.0, 35.0, PATH_WIDTH)
	for i in CONNECTORS:
		var ra: Dictionary = mains[rng.randi() % mains.size()]
		var rb: Dictionary = mains[rng.randi() % mains.size()]
		if ra == rb:
			continue
		var pa: Vector3 = _mid_point(ra.points, rng)
		var pb: Vector3 = _mid_point(rb.points, rng)
		if d.arc_m(pa, pb) > 15.0 and d.arc_m(pa, pb) < 90.0:
			var link := _road(d, pa, pb, rng, 6.0, SIDE_ROAD_WIDTH)
			if not _runs_along_roads(d, link, SIDE_ROAD_WIDTH):
				d.add_road(link, SIDE_ROAD_WIDTH, false)

## Obstáculos que as criaturas contornam: decoração com colisor e as estruturas.
static func _place_obstacles(d: PlanetData) -> void:
	for p in d.placements:
		if p.collider > 0.0:
			d.add_obstacle(p.dir, p.size * p.collider + 0.4)
	for st in structures(d):
		d.add_obstacle(st[0], st[1] + 0.5)

## Manchas de terra gasta fora das estradas: a maioria junto às estradas, algumas à volta das
## estruturas, as restantes espalhadas. Nada cresce em cima delas.
static func _place_dirt(d: PlanetData, b: Dictionary, rng: RandomNumberGenerator) -> void:
	var n := int(round(float(b.get("dirt", 140)) * pow(d.radius / DEFAULT_RADIUS, 2.0)))
	var structs := structures(d)
	for i in n:
		var r := rng.randf_range(1.2, 3.5)
		var roll := rng.randf()
		var dir: Vector3
		if roll < 0.2 and not d.roads.is_empty():
			var road: Dictionary = d.roads[rng.randi() % d.roads.size()]
			var pts: PackedVector3Array = road.points
			var p := pts[rng.randi() % pts.size()]
			var side := SphereMath.basis_from_up(p, rng.randf() * TAU).z
			dir = (p + side * tan((road.width * 0.5 + rng.randf_range(3.0, 6.0)) / d.radius)).normalized()
		elif roll < 0.8:
			var st: Array = structs[rng.randi() % structs.size()]
			var side2 := SphereMath.basis_from_up(st[0], rng.randf() * TAU).z
			dir = ((st[0] as Vector3) + side2 * tan(((st[1] as float) + rng.randf_range(2.0, 7.0)) / d.radius)).normalized()
		else:
			dir = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if d.in_relief(dir) or _near_slot(d, dir, r + 1.0):
			continue
		d.add_dirt_patch(dir, r, rng.randf() * TAU, rng.randi() % 4)

## Estrada que corre colada a outras (lado a lado) em vez de se afastar: ignora as pontas
## (onde é normal tocar na estrada de onde sai ou onde chega).
const PARALLEL_GAP_M := 5.0
static func _runs_along_roads(d: PlanetData, path: PackedVector3Array, width: float, parent: Dictionary = {}) -> bool:
	var n := path.size()
	if n < 6:
		return false
	var close := 0
	# Perto da estrada de onde sai, só conta depois do primeiro terço (no início é normal).
	var skip_parent := 4 # ~8 m: o arranque junto à estrada-mãe
	for i in range(3, n - 3):
		var near := false
		for r in d.roads:
			if r == parent and i < skip_parent:
				continue
			var lim: float = (width + float(r.width)) * 0.5 + PARALLEL_GAP_M
			for q: Vector3 in r.points:
				if d.arc_m(path[i], q) < lim:
					near = true
					break
			if near:
				break
		if near:
			close += 1
	return close > (n - 6) * 0.25

## Círculo de raio `metres` à volta de `center` (estrada fechada).
static func _ring(d: PlanetData, center: Vector3, metres: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var start := d.toward_point(center, SphereMath.basis_from_up(center).z + center, metres)
	var n := maxi(12, int(TAU * metres / ROAD_STEP_M))
	for i in n:
		out.append(start.rotated(center, TAU * i / n).normalized())
	return out

static func _mid_point(pts: PackedVector3Array, rng: RandomNumberGenerator) -> Vector3:
	return pts[rng.randi_range(int(pts.size() * 0.2), int(pts.size() * 0.8))]

## Caminho que sai de um ponto de uma das `parents` para o lado, com `min_m`–`max_m` de comprimento.
static func _add_branch(d: PlanetData, parents: Array, rng: RandomNumberGenerator, min_m: float, max_m: float, width: float) -> void:
	if parents.is_empty():
		return
	var road: Dictionary = parents[rng.randi() % parents.size()]
	var pts: PackedVector3Array = road.points
	if pts.size() < 6:
		return
	var i := rng.randi_range(int(pts.size() * 0.2), int(pts.size() * 0.8))
	var from := pts[i]
	var tangent := (pts[mini(pts.size() - 1, i + 1)] - pts[maxi(0, i - 1)]).normalized()
	var side := from.cross(tangent).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
	var length := rng.randf_range(min_m, max_m) / d.radius
	var to := (from + (side + tangent * rng.randf_range(-0.6, 0.6)).normalized() * tan(length)).normalized()
	var path := _road(d, from, to, rng, 3.5, width)
	if path.size() >= 3 and not _runs_along_roads(d, path, width, road):
		d.add_road(path, width, false)

## Estrada de `a` a `b`: caminho com curvas e desviado de todas as estruturas.
static func _road(d: PlanetData, a: Vector3, b: Vector3, rng: RandomNumberGenerator, wiggle_m: float, width: float) -> PackedVector3Array:
	# Suavizar ANTES de afastar das estruturas (suavizar depois puxava-as para cima delas).
	var path := _smooth(road_path(d, a, b, rng, wiggle_m), 4)
	var hw := width * 0.5
	# Afastar e alisar alternados; no fim, preencher com pontos intermédios e afastar outra vez.
	for k in 5:
		if k in [1, 2]:
			path = _smooth(path, 1)
		if k >= 3:
			path = _densify(path, ROAD_STEP_M)
		for st in structures(d):
			_go_around(d, path, st[0], st[1] + hw + 0.8)
	return path

## Empurra para fora do círculo (centro `sd`, raio `metres`) os pontos do caminho que lá
## estão, TODOS para o mesmo lado (o lado por onde a estrada entra): assim a estrada contorna
## a estrutura em vez de se partir ao meio.
static func _go_around(d: PlanetData, path: PackedVector3Array, sd: Vector3, metres: float) -> void:
	var need := metres / d.radius
	var first := -1
	for i in path.size():
		if path[i].angle_to(sd) < need:
			first = i
			break
	if first < 0:
		return
	var t := path[mini(first + 1, path.size() - 1)] - path[maxi(first - 1, 0)]
	var n := sd.cross(t).normalized() # perpendicular à estrada, no plano tangente
	if n.length() < 0.5:
		n = SphereMath.basis_from_up(sd).x
	var entry := path[maxi(first - 1, 0)] - sd
	var side := 1.0 if entry.dot(n) >= 0.0 else -1.0
	for i in path.size():
		var p := path[i]
		if p.angle_to(sd) >= need:
			continue
		var away := p - sd * p.dot(sd)
		var along := away - n * away.dot(n) # componente ao longo da estrada
		# Lado escolhido: o ponto vai para a borda do círculo desse lado, mantendo o avanço.
		var off := clampf(along.length() / tan(need), 0.0, 1.0)
		var dir := (along.normalized() * off + n * side * sqrt(maxf(1.0 - off * off, 0.0))) if along.length() > 1e-6 else n * side
		path[i] = (sd + dir.normalized() * tan(need)).normalized()

## Acrescenta pontos onde dois seguidos estão a mais de `max_m` metros.
static func _densify(path: PackedVector3Array, max_m: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in path.size():
		if i > 0:
			var a := path[i - 1]
			var b := path[i]
			var n := int(ceil(a.angle_to(b) * DEFAULT_RADIUS / max_m))
			for j in range(1, n):
				out.append(a.slerp(b, float(j) / n).normalized())
		out.append(path[i])
	return out

## Suaviza um caminho (média com os vizinhos), mantendo as pontas.
static func _smooth(path: PackedVector3Array, passes: int) -> PackedVector3Array:
	for k in passes:
		var out := path.duplicate()
		for i in range(1, path.size() - 1):
			out[i] = (path[i - 1] + path[i] * 2.0 + path[i + 1]).normalized()
		path = out
	return path

static func _nearest_road_point(d: PlanetData, dir: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_a := INF
	for r in d.roads:
		for p: Vector3 in r.points:
			var a := p.angle_to(dir)
			if a < best_a:
				best_a = a
				best = p
	return best

## Caminho de `a` a `b` pelo círculo máximo, com curvas laterais (sinusoide com fase e
## frequência aleatórias, nula nas pontas), amostrado de ROAD_STEP_M em ROAD_STEP_M metros.
static func road_path(d: PlanetData, a: Vector3, b: Vector3, rng: RandomNumberGenerator, wiggle_m: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var arc := a.angle_to(b) * d.radius
	var n := maxi(2, int(arc / ROAD_STEP_M))
	var axis := a.cross(b).normalized()
	if axis.length() < 0.5:
		axis = a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT).normalized()
	var freq := rng.randf_range(0.5, 1.3) # curvas largas (estilo estrada de rali), não ziguezagues
	var phase := rng.randf() * TAU
	var amp := wiggle_m / d.radius
	for i in n + 1:
		var t := float(i) / n
		var p := a.slerp(b, t).normalized()
		var off := sin(t * PI) * sin(t * TAU * freq + phase) * amp
		# `axis` é perpendicular ao plano do caminho: somá-lo desvia o ponto para o lado.
		out.append((p + axis * off).normalized())
	return out

## Relva procedimental: muitos tufos baratos, uniformes, fora das zonas livres (postos etc.).
## Sem verificação de sobreposição (é relva).
static func _place_turf(d: PlanetData, b: Dictionary, p_seed: int) -> void:
	var t: Dictionary = b.get("turf", {})
	if t.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p_seed * 977 + 5)
	var n := int(4.0 * PI * d.radius * d.radius * float(t.density))
	var spots := d.flat_spots.map(func(s: Dictionary) -> Array: return [s.dir, cos(s.angle * 0.8)])
	var near_road := d.road_cells()
	for i in n:
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var blocked := false
		for sp in spots:
			if dir.dot(sp[0]) > sp[1]:
				blocked = true
				break
		if blocked:
			continue
		if near_road.has(d.road_cell_of(dir)) and d.road_clearance(dir) < 0.2:
			continue
		if d.in_relief(dir) and d.slope_deg(dir) > MAX_SLOPE_DEG:
			continue
		if _near_slot(d, dir, -0.6): # nada de relva em cima dos slots e talhões
			continue
		d.turf_dirs.append(dir)
		d.turf_sizes.append(rng.randf_range(t.size[0], t.size[1]))
		d.turf_yaws.append(rng.randf() * TAU)

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
			if d.road_clearance(c) < clear:
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
