class_name PlanetData
extends RefCounted
## Dados de um planeta gerado (sem cena). Produzido por PlanetGenerator.generate().
## Direções são vetores unitários a partir do centro do planeta.

var seed: int
var biome: String
var radius: float
var height_amp: float
var noise: FastNoiseLite
## [{kind: String (caminho no kit), dir: Vector3, yaw: float, size: float (altura em m),
##   clear: float (raio livre em m), outline: bool, collider: float (raio do colisor / altura; 0 = sem)}]
var placements: Array[Dictionary] = []
## Pontos "à porta": onde a estrada passa em frente a cada posto (e ao covil). As estruturas
## viram-se para eles.
var post_doors: Array[Vector3] = []
var lair_door: Vector3
## Praça circular à volta do posto avançado (as estradas para os postos saem dela).
var plaza_radius_m := 0.0
## Manchas de terra fora das estradas: [{dir, radius (m), yaw, shape (0..3)}]
var dirt_patches: Array[Dictionary] = []
## Estradas: [{points: PackedVector3Array (direções ao longo do eixo), width: float (m), main: bool}]
var roads: Array[Dictionary] = []
var _road_grid := {} # célula -> [[ponto (m), meia largura]]
const ROAD_CELL := 6.0

## Distância (m) do ponto `dir` à berma da estrada mais próxima (negativa = em cima da estrada).
## Devolve INF se não houver estrada por perto.
func road_clearance(dir: Vector3) -> float:
	return _clearance(_road_grid, dir)

## Rios de ácido: [{points: PackedVector3Array (direções ao longo do eixo), width: float (m)}].
## Também entram na grelha das estradas, para a decoração e o relevo se afastarem deles.
var rivers: Array[Dictionary] = []
## Pontes onde as estradas cruzam os rios: [{points (direções da estrada), width (m)}].
var bridges: Array[Dictionary] = []
## Bolhas de O₂ (direções).
var o2_bubbles: Array[Vector3] = []
var _river_grid := {}
var _bridge_grid := {}

func add_river(points: PackedVector3Array, width: float) -> void:
	rivers.append({"points": points, "width": width})
	_index_points(_river_grid, points, width)
	_index_road(points, width)

func add_bridge(points: PackedVector3Array, width: float) -> void:
	bridges.append({"points": points, "width": width})
	_index_points(_bridge_grid, points, width)

## Distância (m) à margem do rio mais próximo (negativa = dentro do rio; INF = longe).
func river_clearance(dir: Vector3) -> float:
	return _clearance(_river_grid, dir)

## Distância (m) à borda da ponte mais próxima (negativa = em cima da ponte).
func bridge_clearance(dir: Vector3) -> float:
	return _clearance(_bridge_grid, dir)

## No ácido (dentro de um rio e fora das pontes)?
func in_acid(dir: Vector3) -> bool:
	return river_clearance(dir) < 0.0 and bridge_clearance(dir) > 0.0

func _clearance(grid: Dictionary, dir: Vector3) -> float:
	var p := dir.normalized() * radius
	var k := Vector3i((p / ROAD_CELL).floor())
	var best := INF
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var cell = grid.get(k + Vector3i(x, y, z))
				if cell == null:
					continue
				for e in cell:
					best = minf(best, p.distance_to(e[0]) - e[1])
	return best

func _index_points(grid: Dictionary, points: PackedVector3Array, width: float) -> void:
	for d in points:
		var p := d * radius
		var k := Vector3i((p / ROAD_CELL).floor())
		if not grid.has(k):
			grid[k] = []
		grid[k].append([p, width * 0.5])

func road_cell_of(dir: Vector3) -> Vector3i:
	return Vector3i((dir.normalized() * radius / ROAD_CELL).floor())

## Células com estrada nelas ou ao lado (para saltar a verificação fina longe das estradas).
func road_cells() -> Dictionary:
	var out := {}
	for k: Vector3i in _road_grid:
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					out[k + Vector3i(x, y, z)] = true
	return out

func _index_road(points: PackedVector3Array, width: float) -> void:
	_index_points(_road_grid, points, width)

func add_road(points: PackedVector3Array, width: float, main: bool, closed := false) -> void:
	roads.append({"points": points, "width": width, "main": main, "closed": closed})
	_index_road(points, width)

func add_dirt_patch(dir: Vector3, radius_m: float, yaw: float, shape: int) -> void:
	dirt_patches.append({"dir": dir, "radius": radius_m, "yaw": yaw, "shape": shape})
	_index_road(PackedVector3Array([dir]), radius_m * 2.0) # meia largura = raio da mancha

## Ponto a `metres` de `from` na direção de `toward` (ao longo da superfície).
func toward_point(from: Vector3, toward: Vector3, metres: float) -> Vector3:
	var t := toward - from * toward.dot(from)
	if t.length() < 0.0001:
		t = SphereMath.basis_from_up(from).z
	return (from + t.normalized() * tan(metres / radius)).normalized()

## Obstáculos para as criaturas contornarem (árvores, pedregulhos, estruturas).
var _obstacle_grid := {} # célula -> [[ponto (m), raio (m)]]
const OBSTACLE_CELL := 6.0

func add_obstacle(dir: Vector3, radius_m: float) -> void:
	var p := dir.normalized() * radius
	var k := Vector3i((p / OBSTACLE_CELL).floor())
	if not _obstacle_grid.has(k):
		_obstacle_grid[k] = []
	_obstacle_grid[k].append([p, radius_m])

## Obstáculos perto de `dir`: [[ponto à superfície (m, espaço do planeta), raio (m)], …].
func obstacles_near(dir: Vector3) -> Array:
	var p := dir.normalized() * radius
	var k := Vector3i((p / OBSTACLE_CELL).floor())
	var out := []
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var cell = _obstacle_grid.get(k + Vector3i(x, y, z))
				if cell != null:
					out.append_array(cell)
	return out

## Relva procedimental (tufos leves): direção, tamanho e rotação de cada tufo.
var turf_dirs := PackedVector3Array()
var turf_sizes := PackedFloat32Array()
var turf_yaws := PackedFloat32Array()
## Postos dos colonos (direções).
var posts: Array[Vector3] = []
var outpost_dir: Vector3
## Slots de edifícios do posto (direções), à volta da base. Ver PlanetGenerator._place_outpost_slots.
var outpost_slots: Array[Vector3] = []
var lair_dir: Vector3
## Zonas aplanadas: [{dir, angle (rad), h}] — postos, posto avançado e covil.
var flat_spots: Array[Dictionary] = []

## Peças de relevo (penhascos, colinas, montanhas): [{kind, dir, basis (x = lado, y = cima,
##   z = frente, no plano tangente), scale (m por m da peça), height_scale, cos_reach}]
var reliefs: Array[Dictionary] = []

func add_relief(kind: String, dir: Vector3, yaw: float, scale: float, height_scale: float) -> void:
	var pc := ReliefKit.piece(kind)
	var reach: float = (pc.radius * scale + 0.5) / radius
	reliefs.append({"kind": kind, "dir": dir.normalized(), "basis": SphereMath.basis_from_up(dir.normalized(), yaw),
		"scale": scale, "height_scale": height_scale, "cos_reach": cos(reach)})

## Ponto local (m da peça, sem escala) de `dir` na peça `r` (projeção gnomónica no plano tangente).
func relief_local(r: Dictionary, dir: Vector3) -> Vector2:
	var c: Vector3 = r.dir
	var p := dir / dir.dot(c) - c
	var b: Basis = r.basis
	var k: float = radius / float(r.scale)
	return Vector2(p.dot(b.x) * k, p.dot(b.z) * k)

## Direção do ponto local (x, z) da peça `r` (inverso de relief_local).
func relief_dir(r: Dictionary, x: float, z: float) -> Vector3:
	var b: Basis = r.basis
	var k: float = float(r.scale) / radius
	return ((r.dir as Vector3) + (b.x * x + b.z * z) * k).normalized()

## Altura somada pelas peças de relevo em `dir` (0 fora delas).
func relief_height(dir: Vector3) -> float:
	var d := dir.normalized()
	var best := 0.0
	for r in reliefs:
		if d.dot(r.dir) < r.cos_reach:
			continue
		var l := relief_local(r, d)
		var h := ReliefKit.sample(ReliefKit.piece(r.kind), l.x, l.y)
		if h > 0.0:
			best = maxf(best, h * float(r.height_scale))
	return best

## Dentro da área de alguma peça de relevo?
func in_relief(dir: Vector3) -> bool:
	var d := dir.normalized()
	for r in reliefs:
		if d.dot(r.dir) < r.cos_reach:
			continue
		var l := relief_local(r, d)
		if ReliefKit.sample(ReliefKit.piece(r.kind), l.x, l.y) >= 0.0:
			return true
	return false

## Altura do terreno (m, acima do raio) na direção `dir`, com o relevo.
func height_at(dir: Vector3) -> float:
	var d := dir.normalized()
	return base_height_at(d) + relief_height(d)

## Altura do chão por baixo do relevo (ruído + zonas aplanadas).
func base_height_at(dir: Vector3) -> float:
	var d := dir.normalized()
	var h := noise.get_noise_3dv(d * radius) * height_amp
	for s in flat_spots:
		var ang := d.angle_to(s.dir)
		var r: float = s.angle
		if ang < r:
			var w := 1.0 - smoothstep(r * 0.55, r, ang)
			h = lerpf(h, s.h, w)
	return h

## Ponto da superfície na direção `dir` (coordenadas locais do planeta).
func surface_point(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	return d * (radius + height_at(d))

## Normal do terreno (diferenças finitas sobre a superfície).
func normal_at(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var t1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := d.cross(t1).normalized()
	var e := 0.5 / radius # ~0,5 m
	var p := surface_point(d)
	var a := surface_point(d + t1 * e) - p
	var b := surface_point(d + t2 * e) - p
	var n := a.cross(b).normalized()
	return n if n.dot(d) > 0.0 else -n

## Inclinação do terreno em graus (0 = plano).
func slope_deg(dir: Vector3) -> float:
	return rad_to_deg(normal_at(dir).angle_to(dir.normalized()))

## Distância à superfície (arco, em metros) entre duas direções.
func arc_m(a: Vector3, b: Vector3) -> float:
	return a.angle_to(b) * radius
