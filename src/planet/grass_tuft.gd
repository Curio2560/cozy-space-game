class_name GrassTuft
extends RefCounted
## Tufo de relva procedimental leve: `blades` folhas em triângulo, inclinadas em leque.
## Cor por vértice (base escura, ponta clara) e alfa = altura relativa (para o vento).
## Normais para cima, para a relva ter os mesmos tons que o chão. Altura 1 (escala por instância).

static var _cache: Dictionary = {}

static func mesh(color: Color, blades := 4) -> ArrayMesh:
	var key := color.to_html() + str(blades)
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var base := Color(color.r * 0.75, color.g * 0.75, color.b * 0.75, 0.0)
	for i in blades:
		var ang := TAU * float(i) / blades + rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var off := dir * rng.randf_range(0.0, 0.22)
		var h := rng.randf_range(0.7, 1.0)
		var lean := dir * rng.randf_range(0.15, 0.4) * h
		var w := rng.randf_range(0.07, 0.12)
		var tip_col := Color(minf(color.r * 1.15, 1.0), minf(color.g * 1.15, 1.0), minf(color.b * 1.15, 1.0), 1.0)
		verts.append_array([off - side * w, off + side * w, off + lean + Vector3(0, h, 0)])
		cols.append_array([base, base, tip_col])
		norms.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = m
	return m
