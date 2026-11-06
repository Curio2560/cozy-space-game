class_name KitUtil
extends RefCounted
## Utilitários para os modelos do kit, que vêm com escalas muito diferentes entre si.

## Caixa envolvente de todas as malhas sob `root`, no espaço local de `root`.
static func local_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes(root):
		var b: AABB = _relative(mi, root) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Escala `root` uniformemente para a altura `h` (metros) e assenta-o no chão (y = 0 local ao pai).
static func fit_height(root: Node3D, h: float) -> void:
	root.scale = Vector3.ONE
	var box := local_aabb(root)
	if box.size.y <= 0.0:
		return
	var k := h / box.size.y
	root.scale = Vector3.ONE * k
	root.position.y -= box.position.y * k

## Transformação de `n` no espaço de `root` (funciona fora da árvore de cena).
static func _relative(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur != null:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

static var _single_cache: Dictionary = {}

## Para modelos do kit com uma só malha (natureza, pickups): a malha, a sua transformação
## relativa à raiz da cena, o material e a caixa envolvente no espaço da raiz. Em cache.
## Caminhos "nature/X" são modelos .obj do pack de natureza (cores por material, várias
## superfícies): devolve também "palette": true para serem pintados pela paleta do bioma.
static func single_mesh(kit_path: String) -> Dictionary:
	if _single_cache.has(kit_path):
		return _single_cache[kit_path]
	if kit_path.begins_with("mdvl/"):
		# Modelos com paleta em textura (pack "mdvl"): recoloridos pela cor `recolor` do bioma.
		var scene_root: Node3D = (load("res://assets/" + kit_path + ".glb") as PackedScene).instantiate()
		var mi0: MeshInstance3D = _meshes(scene_root)[0]
		var xf0 := _relative(mi0, scene_root)
		var tex := (mi0.get_active_material(0) as BaseMaterial3D).albedo_texture
		var md := {"mesh": mi0.mesh, "xform": xf0, "material": null, "aabb": xf0 * mi0.get_aabb(),
			"palette": false, "recolor": "Grass", "texture": tex}
		scene_root.free()
		_single_cache[kit_path] = md
		return md
	if kit_path.begins_with("nature/"):
		var mesh: Mesh = load("res://assets/" + kit_path + ".obj")
		assert(mesh != null, "modelo em falta: %s" % kit_path)
		var nat := {"mesh": mesh, "xform": Transform3D.IDENTITY, "material": null, "aabb": mesh.get_aabb(), "palette": true}
		_single_cache[kit_path] = nat
		return nat
	var root: Node3D = (load("res://assets/kit/" + kit_path + ".gltf") as PackedScene).instantiate()
	var mis := _meshes(root)
	assert(mis.size() == 1, "%s tem %d malhas" % [kit_path, mis.size()])
	var mi := mis[0]
	var xf := _relative(mi, root)
	var info := {"mesh": mi.mesh, "xform": xf, "material": mi.get_active_material(0), "aabb": xf * mi.get_aabb(), "palette": false}
	root.free()
	_single_cache[kit_path] = info
	return info

static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
