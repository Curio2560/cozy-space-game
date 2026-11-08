class_name ReliefKit
extends RefCounted
## Peças do terreno modular (assets/terrain/*.obj, assentes em Y=0 com a borda toda a Y=0)
## transformadas num mapa de alturas visto de cima e SUAVIZADO: as paredes a pique do pack
## viram encostas, para o rover conseguir subir. O planeta soma esta altura à do chão, e a
## malha, a colisão e height_at saem todos deste mesmo mapa. Em cache por tipo.

const CELL := 0.5 # m por célula do mapa de alturas (escala 1)
const BLUR_CELLS := 6 # raio do desfoque (células), aplicado 2 vezes
const EDGE := 0.02 # abaixo disto conta como fora da peça

## Peças usadas no planeta (as de "Terrain_" quase não têm relevo e ficavam invisíveis).
const KINDS := [
	"SM_Cliffs_03", "SM_Cliffs_06", "SM_Cliffs_08", "SM_Cliffs_09", "SM_Cliffs_11", "SM_Cliffs_12",
	"SM_Cliffs_13", "SM_Cliffs_15", "SM_Cliffs_16", "SM_Cliffs_18",
	"SM_Hills_01", "SM_Hills_02", "SM_Hills_03", "SM_Hills_04", "SM_Hills_05",
	"SM_Mountains_11", "SM_Mountains_12", "SM_Mountains_14",
]

static var _cache := {}

## {half: float (meia largura do mapa), radius: float (raio que contém a peça), top: float,
##  n: int, grid: PackedFloat32Array (altura por célula, 0 fora), grad: float (maior
##  inclinação do mapa, dy/dx)}
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
	var src_half := 0.0
	for p in tris:
		src_half = maxf(src_half, maxf(absf(p.x), absf(p.z)))
	# Margem para o desfoque espalhar a peça para fora da borda original.
	var half := src_half + BLUR_CELLS * 2 * CELL
	var n := int(ceil(half * 2.0 / CELL)) + 1
	var grid := PackedFloat32Array()
	grid.resize(n * n)
	grid.fill(0.0)
	for t in range(0, tris.size(), 3):
		_raster(grid, n, half, tris[t], tris[t + 1], tris[t + 2])
	for k in 2:
		grid = _blur(grid, n, BLUR_CELLS)
	var top := 0.0
	var radius := 0.0
	var grad := 0.0
	for iz in n:
		for ix in n:
			var h := grid[iz * n + ix]
			top = maxf(top, h)
			if h > EDGE:
				radius = maxf(radius, Vector2(ix * CELL - half, iz * CELL - half).length() + CELL)
			if ix + 1 < n and iz + 1 < n:
				# Inclinação em qualquer direção (gradiente completo, não só pelos eixos).
				var gx := (grid[iz * n + ix + 1] - h) / CELL
				var gz := (grid[(iz + 1) * n + ix] - h) / CELL
				grad = maxf(grad, sqrt(gx * gx + gz * gz))
	var out := {"half": half, "radius": radius, "top": top, "n": n, "grid": grid, "grad": grad}
	_cache[kind] = out
	return out

## Altura da peça (m, escala 1) no ponto local (x, z), bilinear; -1 fora do mapa ou onde a
## peça já não tem altura.
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
	var h := lerpf(lerpf(g[iz * n + ix], g[iz * n + ix + 1], tx), lerpf(g[(iz + 1) * n + ix], g[(iz + 1) * n + ix + 1], tx), tz)
	return h if h > EDGE else -1.0

## Desfoque de caixa separável (horizontal e depois vertical).
static func _blur(g: PackedFloat32Array, n: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(n * n)
	for iz in n:
		for ix in n:
			var s := 0.0
			for k in range(-r, r + 1):
				s += g[iz * n + clampi(ix + k, 0, n - 1)]
			tmp[iz * n + ix] = s / (2 * r + 1)
	var out := PackedFloat32Array()
	out.resize(n * n)
	for iz in n:
		for ix in n:
			var s := 0.0
			for k in range(-r, r + 1):
				s += tmp[clampi(iz + k, 0, n - 1) * n + ix]
			out[iz * n + ix] = s / (2 * r + 1)
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
