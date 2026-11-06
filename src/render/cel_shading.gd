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
## `extra_tint` multiplica a cor (p. ex. o tom do bioma nos modelos do kit).
static func material_for(src: Material, smooth_outline := false, extra_tint := Color.WHITE) -> ShaderMaterial:
	var tex: Texture2D = null
	var tint := Color.WHITE
	if src is BaseMaterial3D:
		tex = (src as BaseMaterial3D).albedo_texture
		tint = (src as BaseMaterial3D).albedo_color
	tint *= extra_tint
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
	var out := _copy_with_smooth_normals(mesh as ArrayMesh)
	_mesh_cache[mesh] = out
	return out

static func _copy_with_smooth_normals(src: ArrayMesh) -> ArrayMesh:
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
	return out

static var _palette_cache: Dictionary = {}

## Cor de um material de modelo com cores por material (pack de natureza): a cor da paleta
## para o nome do material (sem sufixos ".001"), ou a cor original convertida para sRGB.
static func palette_color(src: Material, palette: Dictionary) -> Color:
	var name := src.resource_name.get_slice(".", 0) if src else ""
	if palette.has(name):
		return palette[name]
	if src is BaseMaterial3D:
		return (src as BaseMaterial3D).albedo_color.linear_to_srgb()
	return Color.MAGENTA

## Malha com uma só superfície em que cada vértice leva a cor da paleta do seu material
## original ({nome do material: Color}) e a normal suavizada na tangente (para o contorno).
## Um modelo do pack de natureza fica com 1 draw call (+1 do contorno) em vez de 2 por cor.
## Partilhada por (malha, paleta).
## Usar com `vertex_color_material()` como material_override.
static func palette_mesh(mesh: Mesh, palette: Dictionary) -> ArrayMesh:
	var key := [mesh.get_instance_id(), hash(palette)]
	if not _palette_cache.has(key):
		_palette_cache[key] = _merge_with_palette(mesh, palette)
	return _palette_cache[key]

## Material partilhado para malhas com cor por vértice.
static func vertex_color_material(outline := true) -> ShaderMaterial:
	var key := "vcolor|" + str(outline)
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = CEL_SHADER
	m.set_shader_parameter("use_vertex_color", true)
	if outline:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("use_vertex_color", true)
		o.set_shader_parameter("use_tangent_normals", true)
		m.next_pass = o
	_cache[key] = m
	return m

static func _merge_with_palette(mesh: Mesh, palette: Dictionary) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	for i in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var base := verts.size()
		var c := palette_color(mesh.surface_get_material(i), palette)
		verts.append_array(v)
		normals.append_array(n)
		for k in v.size():
			colors.append(c)
		var si = arr[Mesh.ARRAY_INDEX]
		if si == null or (si as PackedInt32Array).is_empty():
			for k in v.size():
				idx.append(base + k)
		else:
			for k in (si as PackedInt32Array):
				idx.append(base + k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = _smoothed_normal_tangents(verts, normals)
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.set_meta(&"cel_outline_ready", true)
	return out

static var _recolor_cache: Dictionary = {}

## Para modelos com a cor numa textura-paleta: lê a cor da textura em cada vértice e troca-a
## por `target`, mantendo a variação de claro/escuro do original (relativa à média da malha).
## Uma superfície com cor por vértice; usar com `vertex_color_material()`.
static func recolor_textured_mesh(mesh: Mesh, texture: Texture2D, target: Color) -> ArrayMesh:
	var key := [mesh.get_instance_id(), target.to_html()]
	if _recolor_cache.has(key):
		return _recolor_cache[key]
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var lums := PackedFloat32Array()
	var idx := PackedInt32Array()
	for i in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var base := verts.size()
		verts.append_array(v)
		normals.append_array(arr[Mesh.ARRAY_NORMAL])
		for k in v.size():
			var px := Vector2i(clampi(int(uv[k].x * w), 0, w - 1), clampi(int(uv[k].y * h), 0, h - 1))
			lums.append(img.get_pixelv(px).get_luminance())
		var si = arr[Mesh.ARRAY_INDEX]
		if si == null or (si as PackedInt32Array).is_empty():
			for k in v.size():
				idx.append(base + k)
		else:
			for k in (si as PackedInt32Array):
				idx.append(base + k)
	var mean := 0.0
	for l in lums:
		mean += l
	mean = maxf(mean / maxf(lums.size(), 1.0), 0.001)
	var colors := PackedColorArray()
	for l in lums:
		var k := clampf(l / mean, 0.7, 1.35)
		colors.append(Color(target.r * k, target.g * k, target.b * k, 1.0).clamp())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = _smoothed_normal_tangents(verts, normals)
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_recolor_cache[key] = out
	return out

static func flat_with_outline(c: Color) -> ShaderMaterial:
	return material_for(_flat_src(c), true)

static func flat_no_outline(c: Color) -> ShaderMaterial:
	return material_no_outline(_flat_src(c))

static var _flat_src_cache: Dictionary = {}

static func _flat_src(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if _flat_src_cache.has(k):
		return _flat_src_cache[k]
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(c)
	var src := StandardMaterial3D.new()
	src.albedo_texture = ImageTexture.create_from_image(img)
	_flat_src_cache[k] = src
	return src

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
static func material_no_outline(src: Material, extra_tint := Color.WHITE) -> ShaderMaterial:
	var key := "noline|" + _key_for(src) + "|" + extra_tint.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := material_for(src, false, extra_tint).duplicate() as ShaderMaterial
	m.next_pass = null
	_cache[key] = m
	return m

static func _key_for(src: Material) -> String:
	if src is BaseMaterial3D:
		return _key((src as BaseMaterial3D).albedo_texture, (src as BaseMaterial3D).albedo_color)
	return _key(null, Color.WHITE)

## Material cel-shaded de uma só cor (chão, protótipos). Partilhado por cor.
static func flat(c: Color) -> ShaderMaterial:
	return material_for(_flat_src(c))

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
	_palette_cache.clear()
	_recolor_cache.clear()

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
