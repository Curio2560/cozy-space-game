@tool
extends EditorScenePostImport
## Auto-toonify imported models.
## Select a .glb in the FileSystem dock -> Import tab -> Import Script -> this file -> Reimport.
## Every mesh gets the toon shader (keeping its original colour and texture) plus the outline.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/toon_outline.gdshader")

## Set to false for small props/pickups to save a draw call per mesh.
const ADD_OUTLINE := true

var _outline_mat: ShaderMaterial


func _post_import(scene: Node) -> Object:
	if ADD_OUTLINE:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = OUTLINE_SHADER
	_apply(scene)
	return scene


func _apply(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		var mesh: Mesh = node.mesh
		for i in mesh.get_surface_count():
			var src: Material = mesh.surface_get_material(i)
			var mat := ShaderMaterial.new()
			mat.shader = TOON_SHADER
			if src is BaseMaterial3D:
				mat.set_shader_parameter("albedo", src.albedo_color)
				if src.albedo_texture:
					mat.set_shader_parameter("albedo_texture", src.albedo_texture)
			if ADD_OUTLINE:
				mat.next_pass = _outline_mat
			mesh.surface_set_material(i, mat)
	for child in node.get_children():
		_apply(child)
