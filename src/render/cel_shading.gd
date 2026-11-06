class_name CelShading
extends RefCounted
## Aplica o cel-shading (shader toon + contorno) a qualquer modelo do kit.
## Os modelos do kit usam todos um material com uma paleta (atlas) pequena; há poucas
## paletas diferentes, por isso guardamos um material por paleta e partilhamo-lo.

const CEL_SHADER := preload("res://shaders/cel.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

static var _cache: Dictionary = {} # chave da paleta -> ShaderMaterial
static var _mesh_cache: Dictionary = {} # Mesh original -> ArrayMesh com normais suaves na tangente

## Substitui os materiais de todas as MeshInstance3D sob `root`. Devolve quantas superfícies mudou.
static func apply(root: Node) -> int:
	var count := 0
	for mi in _mesh_instances(root):
		mi.mesh = outline_ready_mesh(mi.mesh)
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			mi.set_surface_override_material(i, material_for(src, true))
			count += 1
	return count

## Material cel-shaded equivalente a `src` (partilhado entre modelos com a mesma paleta).
## `smooth_outline`: a malha foi preparada por `outline_ready_mesh` (normal suave na tangente).
static func material_for(src: Material, smooth_outline := false) -> ShaderMaterial:
	var tex: Texture2D = null
	var tint := Color.WHITE
	if src is BaseMaterial3D:
		tex = (src as BaseMaterial3D).albedo_texture
		tint = (src as BaseMaterial3D).albedo_color
	var key := _key(tex, tint) + ("|smooth" if smooth_outline else "")
	if _cache.has(key):
		return _cache[key]
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("use_tangent_normals", smooth_outline)
	var mat := ShaderMaterial.new()
	mat.shader = CEL_SHADER
	if tex:
		mat.set_shader_parameter("albedo_tex", tex)
		outline.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("albedo_tint", tint)
	mat.next_pass = outline
	_cache[key] = mat
	return mat

## Cópia da malha com a normal média por posição guardada em ARRAY_TANGENT.
## O contorno usa-a para empurrar os vértices sem abrir fendas nas arestas duras.
## A tangente (ao contrário da cor de vértice) é deformada pelos ossos, por isso funciona
## nas personagens animadas. O cel-shading não usa normal maps, logo a tangente está livre.
## Partilhada entre instâncias da mesma malha.
static func outline_ready_mesh(mesh: Mesh) -> Mesh:
	if not (mesh is ArrayMesh):
		return mesh
	if mesh.has_meta(&"cel_outline_ready"):
		return mesh
	if _mesh_cache.has(mesh):
		return _mesh_cache[mesh]
	var src := mesh as ArrayMesh
	var out := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		arrays[Mesh.ARRAY_TANGENT] = _smoothed_normal_tangents(verts, normals)
		var flags := src.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(src.surface_get_primitive_type(i), arrays, [], {}, flags)
		out.surface_set_material(i, src.surface_get_material(i))
		out.surface_set_name(i, src.surface_get_name(i))
	out.set_meta(&"cel_outline_ready", true)
	_mesh_cache[mesh] = out
	return out

static func _smoothed_normal_tangents(verts: PackedVector3Array, normals: PackedVector3Array) -> PackedFloat32Array:
	var sums: Dictionary = {}
	for v in verts.size():
		var k := _pos_key(verts[v])
		sums[k] = sums.get(k, Vector3.ZERO) + (normals[v] if v < normals.size() else Vector3.UP)
	var tangents := PackedFloat32Array()
	tangents.resize(verts.size() * 4)
	for v in verts.size():
		var n: Vector3 = sums[_pos_key(verts[v])]
		n = n.normalized() if n.length_squared() > 0.000001 else (normals[v] if v < normals.size() else Vector3.UP)
		tangents[v * 4] = n.x
		tangents[v * 4 + 1] = n.y
		tangents[v * 4 + 2] = n.z
		tangents[v * 4 + 3] = 1.0
	return tangents

static func _pos_key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 10000.0), roundi(p.y * 10000.0), roundi(p.z * 10000.0))

## Igual a material_for mas sem passe de contorno (relva e detalhes pequenos).
static func material_no_outline(src: Material) -> ShaderMaterial:
	var key := "noline|" + _key_for(src)
	if _cache.has(key):
		return _cache[key]
	var m := material_for(src).duplicate() as ShaderMaterial
	m.next_pass = null
	_cache[key] = m
	return m

static func _key_for(src: Material) -> String:
	if src is BaseMaterial3D:
		return _key((src as BaseMaterial3D).albedo_texture, (src as BaseMaterial3D).albedo_color)
	return _key(null, Color.WHITE)

## Material cel-shaded de uma só cor (chão, protótipos). Partilhado por cor.
static func flat(c: Color) -> ShaderMaterial:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(c)
	var src := StandardMaterial3D.new()
	src.albedo_texture = ImageTexture.create_from_image(img)
	return material_for(src)

## Material de terreno (chão, superfície do planeta): sem rim light nem brilho, que em
## superfícies grandes vistas de lado fazem o horizonte brilhar.
static func terrain(c: Color) -> ShaderMaterial:
	var key := "terrain|" + c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := flat(c).duplicate() as ShaderMaterial
	m.set_shader_parameter("rim_strength", 0.0)
	m.set_shader_parameter("spec_strength", 0.0)
	# A normal do terreno varia devagar: com suavização normal as bandas ficariam esbatidas.
	m.set_shader_parameter("band_softness", 0.004)
	_cache[key] = m
	return m

static func cached_material_count() -> int:
	return _cache.size()

static func clear_cache() -> void:
	_cache.clear()
	_mesh_cache.clear()

static func _key(tex: Texture2D, tint: Color) -> String:
	var img_hash := "none"
	if tex:
		var img := tex.get_image()
		if img:
			img_hash = str(hash(img.get_data())) + "x" + str(img.get_width())
	return img_hash + "|" + tint.to_html()

static func _mesh_instances(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mesh_instances(c))
	return out
