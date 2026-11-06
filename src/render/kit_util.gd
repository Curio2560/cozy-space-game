class_name KitUtil
extends RefCounted
## Utilitários para os modelos do kit, que vêm com escalas muito diferentes entre si.

## Caixa envolvente de todas as malhas sob `root`, no espaço local de `root`.
static func local_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse()
	for mi in _meshes(root):
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
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

static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
