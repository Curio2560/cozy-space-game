class_name BuildingKit
extends RefCounted
## Edifícios montados com o Quaternius Ultimate Modular Sci-Fi Pack (CC0, assets/scifi).
## Um edifício é uma lista de peças {m: módulo, p: posição (m), r: rotação (graus, à volta de Y)}.
## `bake()` junta tudo numa malha com a cor da paleta por vértice (1 draw call + contorno).
## Grelha do pack: paredes de 4 m (altura 4,43 m), chão e telhado em placas de 2 m.

const DIR := "res://assets/scifi/"
const WALL := 4.0
const STOREY := 4.43

## Cores por nome de material do pack. `Accent` muda por edifício (cor de cada colono).
const BASE_PALETTE := {
	"Main": Color("eef0f2"), "Accent": Color("ffb347"), "DarkGrey": Color("5b6070"),
	"DarkAccent": Color("c7782a"), "Black": Color("2a2a33"), "Light": Color("fff3b0"),
	"Glass": Color("8fd8ff"), "Pipes": Color("8a8f9a"),
}
## Cores de destaque das casas dos colonos (uma por posto).
const COLONIST_ACCENTS := [Color("ff8fa3"), Color("6fd6b4"), Color("b79cff"), Color("ffc857")]

static var _bake_cache: Dictionary = {}
static var _modules: Array = []

## Módulos disponíveis (nomes sem extensão). No APK a pasta lista "X.obj.import".
static func modules() -> Array:
	if _modules.is_empty():
		for f in DirAccess.get_files_at(DIR):
			var n := f.trim_suffix(".remap").trim_suffix(".import")
			if n.ends_with(".obj"):
				n = n.trim_suffix(".obj")
				if n not in _modules:
					_modules.append(n)
		_modules.sort()
	return _modules

static func module_mesh(name: String) -> Mesh:
	return load(DIR + name + ".obj")

static func palette_with_accent(accent: Color) -> Dictionary:
	var p := BASE_PALETTE.duplicate()
	p["Accent"] = accent
	p["DarkAccent"] = accent.darkened(0.3)
	return p

static func part_transform(part: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(part.get("r", 0.0)))), part.p)

## Junta as peças numa só malha pintada pela paleta (cor por vértice, normais suaves na
## tangente para o contorno). Em cache por (peças, paleta).
static func bake(parts: Array, palette: Dictionary) -> ArrayMesh:
	var key := [hash(parts), hash(palette)]
	if _bake_cache.has(key):
		return _bake_cache[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for part in parts:
		var src := CelShading.palette_mesh(module_mesh(part.m), palette)
		var arr := src.surface_get_arrays(0)
		var xf := part_transform(part)
		var base := verts.size()
		for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			verts.append(xf * v)
		for n in (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array):
			norms.append((xf.basis * n).normalized())
		cols.append_array(arr[Mesh.ARRAY_COLOR])
		for i in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
			idx.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = CelShading._smoothed_normal_tangents(verts, norms)
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_bake_cache[key] = out
	return out

## Nó pronto: malha cozida em cel-shading com contorno e colisão. Frente (+Z) = porta.
static func build(parts: Array, palette: Dictionary, with_collision := true) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = bake(parts, palette)
	mi.material_override = CelShading.vertex_color_material(true)
	root.add_child(mi)
	if with_collision:
		# Caixa simples em vez da malha completa: milhares de faces por edifício pesam no telemóvel.
		var aabb := mi.mesh.get_aabb()
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = aabb.size
		cs.shape = shape
		cs.position = aabb.get_center()
		body.add_child(cs)
		root.add_child(body)
	return root

## Sala retangular de `nx`×`nz` paredes (de 4 m), centrada na origem, com a porta à frente (+Z).
## `walls`: módulos a usar nas paredes {front: [..], back: [..], left: [..], right: [..]}.
static func room(nx: int, nz: int, walls: Dictionary, roof: Array, floor_m := "FloorTile_Basic", column := "Column_1") -> Array:
	var parts := []
	var hx := nx * WALL * 0.5
	var hz := nz * WALL * 0.5
	for ix in nx * 2:
		for iz in nz * 2:
			var x := -hx + 1.0 + ix * 2.0
			var z := -hz + 1.0 + iz * 2.0
			parts.append({"m": floor_m, "p": Vector3(x, 0, z), "r": 0})
			parts.append({"m": roof[(ix * 7 + iz * 3) % roof.size()], "p": Vector3(x, STOREY, z), "r": 90 * ((ix + iz) % 4)})
	for i in nx:
		var x := -hx + WALL * 0.5 + i * WALL
		# O lado detalhado (branco) das paredes do pack é o de dentro: virado para fora aqui.
		parts.append({"m": walls.front[i % walls.front.size()], "p": Vector3(x, 0, hz), "r": 0})
		parts.append({"m": walls.back[i % walls.back.size()], "p": Vector3(x, 0, -hz), "r": 180})
	for i in nz:
		var z := -hz + WALL * 0.5 + i * WALL
		parts.append({"m": walls.left[i % walls.left.size()], "p": Vector3(-hx, 0, z), "r": -90})
		parts.append({"m": walls.right[i % walls.right.size()], "p": Vector3(hx, 0, z), "r": 90})
	for x in [-hx, hx]:
		for z in [-hz, hz]:
			parts.append({"m": column, "p": Vector3(x, 0, z), "r": 0})
	return parts

## Casa de um colono: 4×4 m, porta à frente, janelas dos lados.
static func colonist_house() -> Array:
	var parts := room(1, 1, {
		"front": ["DoorSingle_Wall_SideA"], "back": ["Wall_1"],
		"left": ["SmallWindows_Wall_SideA"], "right": ["Window_Wall_SideA"],
	}, ["RoofTile_Plate", "RoofTile_SmallVents", "RoofTile_Details", "RoofTile_Plate2"])
	parts.append({"m": "Door_Single", "p": Vector3(0, 0, WALL * 0.5), "r": 0})
	parts.append({"m": "Props_Vessel_Tall", "p": Vector3(1.4, 0, 2.7), "r": 0})
	parts.append({"m": "Props_Crate", "p": Vector3(-1.5, 0, 2.8), "r": 20})
	return parts

## Base (posto avançado): 8×8 m, porta dupla, janelas compridas, cápsula e um caixote à porta (adereços pesados retirados por performance).
static func outpost() -> Array:
	var parts := room(2, 2, {
		"front": ["DoorDouble_Wall_SideA", "LongWindow_Wall_SideA"], "back": ["Wall_2", "Wall_4"],
		"left": ["ThreeWindows_Wall_SideA", "Wall_3"], "right": ["Wall_5", "ThreeWindows_Wall_SideA"],
	}, ["RoofTile_Vents", "RoofTile_Plate", "RoofTile_OrangeVent", "RoofTile_Details", "RoofTile_Pipes1", "RoofTile_SmallVents"], "FloorTile_Basic", "Column_2")
	parts.append({"m": "Door_Double", "p": Vector3(-2.0, 0, WALL), "r": 0})
	for x in [-WALL, WALL]:
		parts.append({"m": "Column_3", "p": Vector3(x * 0.0 + 0.0, 0, x), "r": 0})
	parts.append({"m": "Props_Pod", "p": Vector3(5.6, 0, 3.0), "r": -30})
	parts.append({"m": "Props_Crate", "p": Vector3(1.2, 0, 5.0), "r": 10})
	parts.append({"m": "Props_Teleporter_2", "p": Vector3(-5.0, 0, -3.0), "r": 0})
	return parts
