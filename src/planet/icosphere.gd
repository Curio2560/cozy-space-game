class_name Icosphere
extends RefCounted
## Icosfera unitária subdividida (vértices partilhados). Resultado em cache por nível.

static var _cache: Dictionary = {}

## Devolve [PackedVector3Array vértices unitários, PackedInt32Array índices (triângulos)].
static func build(level: int) -> Array:
	if _cache.has(level):
		return _cache[level]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = []
	for v in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append(v.normalized())
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in level:
		var mid := {}
		var nf: Array = []
		for f in faces:
			var a := _mid(f[0], f[1], verts, mid)
			var b := _mid(f[1], f[2], verts, mid)
			var c := _mid(f[2], f[0], verts, mid)
			nf.append_array([[f[0], a, c], [f[1], b, a], [f[2], c, b], [a, b, c]])
		faces = nf
	var pv := PackedVector3Array(verts)
	var idx := PackedInt32Array()
	for f in faces:
		# Ordem invertida: o Godot usa sentido horário para as faces da frente.
		idx.append_array([f[0], f[2], f[1]])
	_cache[level] = [pv, idx]
	return _cache[level]

## Direções dos vértices da icosfera de nível `level` (centros das regiões de culling):
## nível 0 = 12, nível 1 = 42, nível 2 = 162.
static func region_dirs(level := 1) -> PackedVector3Array:
	return (build(level)[0] as PackedVector3Array)

## Meio-ângulo máximo de uma região (distância angular de um ponto ao centro mais próximo).
static func region_angle(level := 1) -> float:
	var dirs := region_dirs(level)
	var worst := 0.0
	for p in PlanetGenerator.fibonacci_dirs(3000):
		var best := PI
		for d in dirs:
			best = minf(best, p.angle_to(d))
		worst = maxf(worst, best)
	return worst * 1.02

static func _mid(a: int, b: int, verts: Array[Vector3], cache: Dictionary) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if cache.has(key):
		return cache[key]
	verts.append(((verts[a] + verts[b]) * 0.5).normalized())
	cache[key] = verts.size() - 1
	return verts.size() - 1
