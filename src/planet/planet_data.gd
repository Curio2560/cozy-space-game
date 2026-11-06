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
	var p := dir.normalized() * radius
	var k := Vector3i((p / ROAD_CELL).floor())
	var best := INF
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var cell = _road_grid.get(k + Vector3i(x, y, z))
				if cell == null:
					continue
				for e in cell:
					best = minf(best, p.distance_to(e[0]) - e[1])
	return best

func _index_road(points: PackedVector3Array, width: float) -> void:
	for d in points:
		var p := d * radius
		var k := Vector3i((p / ROAD_CELL).floor())
		if not _road_grid.has(k):
			_road_grid[k] = []
		_road_grid[k].append([p, width * 0.5])

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
var lair_dir: Vector3
## Zonas aplanadas: [{dir, angle (rad), h}] — postos, posto avançado e covil.
var flat_spots: Array[Dictionary] = []

## Altura do terreno (m, acima do raio) na direção `dir`.
func height_at(dir: Vector3) -> float:
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
