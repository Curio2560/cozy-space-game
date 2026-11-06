class_name Planet
extends Node3D
## Constrói a cena de um planeta a partir de PlanetData: terreno (icosfera deformada) com
## colisão, decoração em MultiMesh agrupada por 42 regiões (culling por hemisfério),
## colisores simples para árvores e rochas grandes, e marcadores dos postos.

signal built

const ICO_LEVEL := 5
const REGION_LEVEL := 1 # 42 regiões
static var region_angle := -1.0 # calculado uma vez (Icosphere.region_angle)
const POST_MODEL := "base/House_Single"
const OUTPOST_MODEL := "base/Base_Large"
const LAIR_MODEL := "natureza/Rock_Large_3"

var data: PlanetData
var culling_enabled := true
var terrain: MeshInstance3D
var body: StaticBody3D
var _regions: Array[Node3D] = []
var _region_dirs: PackedVector3Array
## Margem angular para objetos altos ainda visíveis para lá do horizonte.
var _tall_margin := 0.2

func build(d: PlanetData) -> void:
	data = d
	for c in get_children():
		c.free()
	_regions.clear()
	_region_dirs = Icosphere.region_dirs(REGION_LEVEL)
	if region_angle < 0.0:
		region_angle = Icosphere.region_angle(REGION_LEVEL)
	var tallest := 0.0
	for p in d.placements:
		tallest = maxf(tallest, p.size)
	_tall_margin = acos(d.radius / (d.radius + d.height_amp * 2.0 + tallest))
	body = StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	_build_terrain()
	_build_props()
	_build_spots()
	built.emit()

## Instâncias de decoração visíveis (soma de todas as MultiMesh). Para testes e DBG.
func prop_instance_count() -> int:
	var n := 0
	for r in _regions:
		for mmi in r.get_children():
			n += (mmi as MultiMeshInstance3D).multimesh.instance_count
	return n

func visible_region_count() -> int:
	return _regions.filter(func(r: Node3D) -> bool: return r.visible).size()

func _process(_delta: float) -> void:
	if not culling_enabled or data == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	update_culling(to_local(cam.global_position))

func update_culling(cam_local: Vector3) -> void:
	for i in _regions.size():
		_regions[i].visible = PlanetCulling.region_visible(_region_dirs[i], cam_local, data.radius - data.height_amp, region_angle, _tall_margin)

func _build_terrain() -> void:
	var ico := Icosphere.build(ICO_LEVEL)
	var dirs: PackedVector3Array = ico[0]
	var idx: PackedInt32Array = ico[1]
	var verts := PackedVector3Array()
	verts.resize(dirs.size())
	for i in dirs.size():
		verts[i] = data.surface_point(dirs[i])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	var faces := PackedVector3Array()
	faces.resize(idx.size())
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var b := verts[idx[t + 1]]
		var c := verts[idx[t + 2]]
		var fn := (c - a).cross(b - a)
		normals[idx[t]] += fn
		normals[idx[t + 1]] += fn
		normals[idx[t + 2]] += fn
		faces[t] = a
		faces[t + 1] = b
		faces[t + 2] = c
	for i in normals.size():
		normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	terrain = MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = mesh
	terrain.material_override = CelShading.terrain(PlanetGenerator.BIOMES[data.biome].ground)
	add_child(terrain)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

func _region_of(dir: Vector3) -> int:
	var best := 0
	var best_dot := -2.0
	for i in _region_dirs.size():
		var dt := dir.dot(_region_dirs[i])
		if dt > best_dot:
			best_dot = dt
			best = i
	return best

func _build_props() -> void:
	# Agrupar transformações por região e tipo.
	var groups := {} # Vector2i(região, id tipo) -> Array[Transform3D]
	var kinds: Array[String] = []
	var outline_of := {}
	for p in data.placements:
		var kind: String = p.kind
		var k := kinds.find(kind)
		if k == -1:
			kinds.append(kind)
			k = kinds.size() - 1
			outline_of[kind] = p.outline
		var info := KitUtil.single_mesh(kind)
		var key := Vector2i(_region_of(p.dir), k)
		if not groups.has(key):
			groups[key] = []
		var xf := _prop_transform(p, info)
		groups[key].append(xf)
		if p.collider > 0.0:
			_add_collider(p)
	for i in _region_dirs.size():
		var r := Node3D.new()
		r.name = "Region%d" % i
		add_child(r)
		_regions.append(r)
	for key: Vector2i in groups:
		var kind := kinds[key.y]
		var info := KitUtil.single_mesh(kind)
		var xfs: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var with_outline: bool = outline_of[kind]
		var mmi := MultiMeshInstance3D.new()
		if info.palette:
			# Pack de natureza: uma superfície com a cor da paleta do bioma por vértice.
			mm.mesh = CelShading.palette_mesh(info.mesh, PlanetGenerator.BIOMES[data.biome].palette)
			mmi.material_override = CelShading.vertex_color_material(with_outline)
		else:
			# Modelos do kit (paleta em textura): tom do bioma por cima.
			var tint: Color = PlanetGenerator.BIOMES[data.biome].get("kit_tint", Color.WHITE)
			mm.mesh = CelShading.outline_ready_mesh(info.mesh) if with_outline else info.mesh
			mmi.material_override = CelShading.material_for(info.material, true, tint) if with_outline else CelShading.material_no_outline(info.material, tint)
		mm.instance_count = xfs.size()
		for j in xfs.size():
			mm.set_instance_transform(j, xfs[j])
		mmi.multimesh = mm
		_regions[key.x].add_child(mmi)

func _prop_transform(p: Dictionary, info: Dictionary) -> Transform3D:
	var dir: Vector3 = p.dir
	var box: AABB = info.aabb
	var s: float = p.size / maxf(box.size.y, 0.001)
	var b := SphereMath.basis_from_up(dir, p.yaw).scaled_local(Vector3.ONE * s)
	var sink: float = p.size * 0.04 # enterra um pouco para não flutuar em declives
	var origin := data.surface_point(dir) - b * Vector3(0, box.position.y, 0) - dir * sink
	return Transform3D(b, origin) * (info.xform as Transform3D)

func _add_collider(p: Dictionary) -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = p.size * p.collider
	cyl.height = p.size
	cs.shape = cyl
	var dir: Vector3 = p.dir
	cs.transform = Transform3D(SphereMath.basis_from_up(dir), data.surface_point(dir) + dir * p.size * 0.5)
	body.add_child(cs)

func _build_spots() -> void:
	for i in data.posts.size():
		_place_model(POST_MODEL, data.posts[i], 3.0, "Post%d" % i)
	_place_model(OUTPOST_MODEL, data.outpost_dir, 4.5, "Outpost")
	_place_model(LAIR_MODEL, data.lair_dir, 4.0, "Lair")

func _place_model(kit_path: String, dir: Vector3, height: float, node_name: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	add_child(holder)
	holder.transform = Transform3D(SphereMath.basis_from_up(dir), data.surface_point(dir))
	var m: Node3D = (load("res://assets/kit/" + kit_path + ".gltf") as PackedScene).instantiate()
	holder.add_child(m)
	KitUtil.fit_height(m, height)
	CelShading.apply(m)
	var box := KitUtil.local_aabb(holder)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	cs.shape = bs
	cs.transform = holder.transform * Transform3D(Basis.IDENTITY, box.get_center())
	body.add_child(cs)
	return holder
