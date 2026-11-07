class_name ReliefKit
extends RefCounted
## Peças do terreno modular (assets/terrain/*.obj, assentes em Y=0 com a borda toda a Y=0):
## triângulos no espaço local da peça e um mapa de alturas visto de cima, para o planeta somar
## a altura da peça à do chão. Em cache por tipo.

const CELL := 0.5 # m por célula do mapa de alturas

## Peças usadas no planeta (as de "Terrain_" quase não têm relevo e ficavam invisíveis).
const KINDS := [
	"SM_Cliffs_03", "SM_Cliffs_06", "SM_Cliffs_08", "SM_Cliffs_09", "SM_Cliffs_11", "SM_Cliffs_12",
	"SM_Cliffs_13", "SM_Cliffs_15", "SM_Cliffs_16", "SM_Cliffs_18",
	"SM_Hills_01", "SM_Hills_02", "SM_Hills_03", "SM_Hills_04", "SM_Hills_05",
	"SM_Mountains_11", "SM_Mountains_12", "SM_Mountains_14",
]

static var _cache := {}

## {tris: PackedVector3Array (3 vértices por triângulo, m), half: float (meia largura),
##  radius: float (raio que contém a peça), top: float, n: int, grid: PackedFloat32Array
##  (altura por célula; -1 = fora da peça)}
static func piece(kind: String) -> Dictionary:
	if _cache.has(kind):
		return _cache[kind]
	var mesh: Mesh = load("res://assets/terrain/" + kind + ".obj")
	assert(mesh != null, "peça de relevo em falta: %s" % kind)
	var tris := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx == null or (idx as PackedInt32Array).is_empty():
			tris.append_array(v)
		else:
			for i in idx:
				tris.append(v[i])
	var half := 0.0
	var radius := 0.0
	var top := 0.0
	for p in tris:
		half = maxf(half, maxf(absf(p.x), absf(p.z)))
		radius = maxf(radius, Vector2(p.x, p.z).length())
		top = maxf(top, p.y)
	var n := int(ceil(half * 2.0 / CELL)) + 1
	var grid := PackedFloat32Array()
	grid.resize(n * n)
	grid.fill(-1.0)
	for t in range(0, tris.size(), 3):
		_raster(grid, n, half, tris[t], tris[t + 1], tris[t + 2])
	var out := {"tris": tris, "half": half, "radius": radius, "top": top, "n": n, "grid": grid}
	_cache[kind] = out
	return out

## Altura da peça (m, escala 1) no ponto local (x, z); -1 fora da peça. Bilinear; as células
## de fora contam como 0 (a borda da peça está a Y=0).
static func sample(pc: Dictionary, x: float, z: float) -> float:
	var half: float = pc.half
	var n: int = pc.n
	var fx := (x + half) / CELL
	var fz := (z + half) / CELL
	if fx < 0.0 or fz < 0.0 or fx > n - 1 or fz > n - 1:
		return -1.0
	var ix := mini(int(fx), n - 2)
	var iz := mini(int(fz), n - 2)
	var tx := fx - ix
	var tz := fz - iz
	var g: PackedFloat32Array = pc.grid
	var a := g[iz * n + ix]
	var b := g[iz * n + ix + 1]
	var c := g[(iz + 1) * n + ix]
	var d := g[(iz + 1) * n + ix + 1]
	if a < 0.0 and b < 0.0 and c < 0.0 and d < 0.0:
		return -1.0
	return lerpf(lerpf(maxf(a, 0.0), maxf(b, 0.0), tx), lerpf(maxf(c, 0.0), maxf(d, 0.0), tx), tz)

## Arestas da borda (usadas por um só triângulo): [a, b, a, b, …] em espaço local.
static func border_edges(pc: Dictionary) -> PackedVector3Array:
	if pc.has("border"):
		return pc.border
	var tris: PackedVector3Array = pc.tris
	var count := {}
	var key := func(p: Vector3) -> Vector3i: return Vector3i((p * 1000.0).round())
	for t in range(0, tris.size(), 3):
		for k in 3:
			var a: Vector3 = tris[t + k]
			var b: Vector3 = tris[t + (k + 1) % 3]
			var ka: Vector3i = key.call(a)
			var kb: Vector3i = key.call(b)
			var e := [ka, kb] if str(ka) < str(kb) else [kb, ka]
			var ek := str(e)
			if count.has(ek):
				count[ek][0] += 1
			else:
				count[ek] = [1, a, b]
	var out := PackedVector3Array()
	for ek in count:
		var c: Array = count[ek]
		if c[0] == 1:
			out.append(c[1])
			out.append(c[2])
	pc.border = out
	return out

static func _raster(grid: PackedFloat32Array, n: int, half: float, a: Vector3, b: Vector3, c: Vector3) -> void:
	var minx := int(floor((minf(a.x, minf(b.x, c.x)) + half) / CELL))
	var maxx := int(ceil((maxf(a.x, maxf(b.x, c.x)) + half) / CELL))
	var minz := int(floor((minf(a.z, minf(b.z, c.z)) + half) / CELL))
	var maxz := int(ceil((maxf(a.z, maxf(b.z, c.z)) + half) / CELL))
	var den := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(den) < 1e-9:
		return # triângulo vertical: as faces vizinhas dão a altura
	for iz in range(maxi(minz, 0), mini(maxz, n - 1) + 1):
		for ix in range(maxi(minx, 0), mini(maxx, n - 1) + 1):
			var px := ix * CELL - half
			var pz := iz * CELL - half
			var w1 := ((b.z - c.z) * (px - c.x) + (c.x - b.x) * (pz - c.z)) / den
			var w2 := ((c.z - a.z) * (px - c.x) + (a.x - c.x) * (pz - c.z)) / den
			var w3 := 1.0 - w1 - w2
			if w1 < -0.001 or w2 < -0.001 or w3 < -0.001:
				continue
			var y := w1 * a.y + w2 * b.y + w3 * c.y
			var i := iz * n + ix
			grid[i] = maxf(grid[i], y)
