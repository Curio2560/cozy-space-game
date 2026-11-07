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
	_build_roads()
	_build_rivers()
	_build_bridges()
	_build_dirt()
	_build_props()
	_build_reliefs() # depois de _build_props: precisa das regiões
	_build_turf()
	_build_spots()
	built.emit()

## Instâncias de decoração visíveis (soma de todas as MultiMesh). Para testes e DBG.
func prop_instance_count() -> int:
	var n := 0
	for r in _regions:
		for mmi in r.get_children():
			if not mmi is MultiMeshInstance3D or mmi.name.begins_with("Turf"):
				continue
			n += (mmi as MultiMeshInstance3D).multimesh.instance_count
	return n

var roads_mesh: MeshInstance3D
const ROAD_LIFT := 0.1
const ROAD_ACROSS := [-1.0, -0.55, 0.0, 0.55, 1.0]
const ROAD_SHADER := preload("res://shaders/road.gdshader")
static var _road_mat: ShaderMaterial

## Estradas: uma faixa por estrada (5 vértices de largura) que segue o relevo, ligeiramente
## acima do chão. A textura (terra, pedrinhas, bermas irregulares) vem do shader
## de estrada. Tudo numa só malha.
func _build_roads() -> void:
	if data.roads.is_empty():
		return
	var col: Color = PlanetGenerator.BIOMES[data.biome].palette.get("Road", Color("d9c49b"))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var w := ROAD_ACROSS.size()
	var road_i := 0
	for road in data.roads:
		var pts: PackedVector3Array = road.points
		var lift := ROAD_LIFT
		road_i += 1
		if road.get("closed", false):
			pts = pts.duplicate()
			pts.append(pts[0]) # fecha a volta
		var hw: float = road.width * 0.5
		var base := verts.size()
		var along := 0.0
		for i in pts.size():
			if i > 0:
				along += data.arc_m(pts[i - 1], pts[i])
			var p := pts[i]
			var t := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
			t = (t - p * t.dot(p)).normalized()
			var side := p.cross(t).normalized()
			for k in w:
				var q: Vector3 = (p + side * (float(ROAD_ACROSS[k]) * hw / data.radius)).normalized()
				verts.append(data.surface_point(q) + q * lift)
				norms.append(q) # normal "para cima": estradas sobrepostas com a mesma luz
				cols.append(col)
				uvs.append(Vector2((float(ROAD_ACROSS[k]) + 1.0) * 0.5, along))
		for i in pts.size() - 1:
			for k in w - 1:
				var a := base + i * w + k
				var b := a + w
				# O Godot usa sentido horário para a face da frente: escolher a ordem em que a
				# normal (regra da mão direita) aponta para DENTRO do planeta.
				var n := (verts[b] - verts[a]).cross(verts[a + 1] - verts[a])
				if n.dot(verts[a]) < 0.0:
					idx.append_array([a, b, a + 1, a + 1, b, b + 1])
				else:
					idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _road_mat == null:
		_road_mat = ShaderMaterial.new()
		_road_mat.shader = ROAD_SHADER
	roads_mesh = MeshInstance3D.new()
	roads_mesh.name = "Roads"
	roads_mesh.mesh = mesh
	roads_mesh.material_override = _road_mat
	roads_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roads_mesh)

var rivers_mesh: MeshInstance3D
var bridge_nodes: Array[MeshInstance3D] = []
const RIVER_LIFT := 0.14
const ACID_SHADER := preload("res://shaders/acid.gdshader")

## Rios de ácido: faixas como as estradas (seguem o relevo), com o shader de ácido.
func _build_rivers() -> void:
	if data.rivers.is_empty():
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var w := ROAD_ACROSS.size()
	for river in data.rivers:
		var pts: PackedVector3Array = river.points
		var hw: float = river.width * 0.5
		var base := verts.size()
		var along := 0.0
		for i in pts.size():
			if i > 0:
				along += data.arc_m(pts[i - 1], pts[i])
			var p := pts[i]
			var t := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
			t = (t - p * t.dot(p)).normalized()
			var side := p.cross(t).normalized()
			# Pontas arredondadas: o rio estreita nos dois últimos pontos.
			var taper := minf(1.0, minf(float(i), float(pts.size() - 1 - i)) * 0.5 + 0.2)
			for k in w:
				var q: Vector3 = (p + side * (float(ROAD_ACROSS[k]) * hw * taper / data.radius)).normalized()
				verts.append(data.surface_point(q) + q * RIVER_LIFT)
				norms.append(q)
				uvs.append(Vector2((float(ROAD_ACROSS[k]) + 1.0) * 0.5, along))
		for i in pts.size() - 1:
			for k in w - 1:
				var a := base + i * w + k
				var b := a + w
				_tri(idx, verts, a, b, a + 1)
				_tri(idx, verts, a + 1, b, b + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = ACID_SHADER
	var acid: Color = PlanetGenerator.BIOMES[data.biome].palette.get("Acid", Color("8cff3a"))
	mat.set_shader_parameter("acid", acid)
	mat.set_shader_parameter("deep", acid.darkened(0.55))
	rivers_mesh = MeshInstance3D.new()
	rivers_mesh.name = "Rivers"
	rivers_mesh.mesh = mesh
	rivers_mesh.material_override = mat
	rivers_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rivers_mesh)

const BRIDGE_DECK := 0.22 # espessura do tabuleiro (m)
const BRIDGE_RAIL := 0.55

## Pontes de madeira: tabuleiro reto da primeira à última ponta, acima do ponto mais alto do
## chão por baixo, com guardas dos lados. Colisão por caixas.
func _build_bridges() -> void:
	bridge_nodes.clear()
	var pal: Dictionary = PlanetGenerator.BIOMES[data.biome].palette
	var wood: Color = pal.get("LightWood", Color("c99a74"))
	var dark: Color = pal.get("Wood", Color("a8735a"))
	var i := 0
	for br in data.bridges:
		var pts: PackedVector3Array = br.points
		var a := data.surface_point(pts[0])
		var b := data.surface_point(pts[pts.size() - 1])
		var top := 0.0
		for p in pts:
			top = maxf(top, data.surface_point(p).length())
		var mid_dir := (a + b).normalized()
		var length := maxf(a.distance_to(b) + 1.0, 5.0) # rios até 3,2 m de largura
		var up := mid_dir
		var fwd := ((b - a) - up * (b - a).dot(up)).normalized()
		var basis := Basis(up.cross(fwd), up, fwd)
		var center := mid_dir * (top + RIVER_LIFT + BRIDGE_DECK * 0.5)
		var width: float = br.width
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var boxes := [
			[Vector3(0, 0, 0), Vector3(width, BRIDGE_DECK, length), wood],
			[Vector3(-width * 0.5 + 0.1, BRIDGE_RAIL * 0.5 + BRIDGE_DECK * 0.5, 0), Vector3(0.18, BRIDGE_RAIL, length), dark],
			[Vector3(width * 0.5 - 0.1, BRIDGE_RAIL * 0.5 + BRIDGE_DECK * 0.5, 0), Vector3(0.18, BRIDGE_RAIL, length), dark],
		]
		var xf := Transform3D(basis, center)
		for bx in boxes:
			_add_box(st, xf * Transform3D(Basis.IDENTITY, bx[0]), bx[1], bx[2])
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = bx[1]
			cs.shape = shape
			cs.transform = xf * Transform3D(Basis.IDENTITY, bx[0])
			body.add_child(cs)
		# Tábuas: riscas escuras de 0,6 em 0,6 m por cima do tabuleiro.
		var z := -length * 0.5 + 0.3
		while z < length * 0.5:
			_add_box(st, xf * Transform3D(Basis.IDENTITY, Vector3(0, BRIDGE_DECK * 0.5, z)), Vector3(width - 0.4, 0.03, 0.08), dark)
			z += 0.6
		var mi := MeshInstance3D.new()
		mi.name = "Bridge%d" % i
		mi.mesh = st.commit()
		mi.material_override = CelShading.vertex_color_material(false)
		add_child(mi)
		bridge_nodes.append(mi)
		i += 1

static func _add_box(st: SurfaceTool, xf: Transform3D, size: Vector3, col: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var arr := bm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for k in ix:
		st.set_color(col)
		st.set_normal((xf.basis * n[k]).normalized())
		st.add_vertex(xf * v[k])

var dirt_mesh: MeshInstance3D
const DIRT_RINGS := [0.35, 0.7, 1.0]
const DIRT_SEGMENTS := 20

## Manchas de terra: discos irregulares que seguem o relevo (como as estradas), com o mesmo
## shader de terra. UV.x vai de 0,5 no centro a 0 na borda (borda irregular do shader).
func _build_dirt() -> void:
	if data.dirt_patches.is_empty():
		return
	var col: Color = PlanetGenerator.BIOMES[data.biome].palette.get("Road", Color("d9c49b"))
	col = Color(col.r * 0.94, col.g * 0.92, col.b * 0.9)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for patch in data.dirt_patches:
		var center: Vector3 = patch.dir
		var b := SphereMath.basis_from_up(center, patch.yaw)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(patch.shape) * 97 + 13
		var radii := PackedFloat32Array()
		for k in DIRT_SEGMENTS:
			radii.append(rng.randf_range(0.65, 1.0)) # forma irregular
		var base := verts.size()
		verts.append(data.surface_point(center) + center * ROAD_LIFT)
		norms.append(center)
		cols.append(col)
		uvs.append(Vector2(0.5, 0.0))
		for ring in DIRT_RINGS.size():
			var rr: float = DIRT_RINGS[ring]
			for k in DIRT_SEGMENTS:
				var ang := TAU * k / DIRT_SEGMENTS
				var off := (b.x * cos(ang) + b.z * sin(ang)) * (float(patch.radius) * rr * radii[k] / data.radius)
				var q := (center + off).normalized()
				verts.append(data.surface_point(q) + q * ROAD_LIFT)
				norms.append(q)
				cols.append(col)
				uvs.append(Vector2(0.5 * (1.0 - rr), ang * float(patch.radius)))
		for k in DIRT_SEGMENTS:
			var k2 := (k + 1) % DIRT_SEGMENTS
			_tri(idx, verts, base, base + 1 + k, base + 1 + k2)
			for ring in DIRT_RINGS.size() - 1:
				var a := base + 1 + ring * DIRT_SEGMENTS
				var c := a + DIRT_SEGMENTS
				_tri(idx, verts, a + k, c + k, c + k2)
				_tri(idx, verts, a + k, c + k2, a + k2)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _road_mat == null:
		_road_mat = ShaderMaterial.new()
		_road_mat.shader = ROAD_SHADER
	dirt_mesh = MeshInstance3D.new()
	dirt_mesh.name = "Dirt"
	dirt_mesh.mesh = mesh
	dirt_mesh.material_override = _road_mat
	dirt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dirt_mesh)

## Triângulo com a face da frente virada para fora do planeta (sentido horário visto de fora).
static func _tri(idx: PackedInt32Array, verts: PackedVector3Array, a: int, b: int, c: int) -> void:
	var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if n.dot(verts[a]) < 0.0:
		idx.append_array([a, b, c])
	else:
		idx.append_array([a, c, b])

func turf_instance_count() -> int:
	return _turf_count

var _turf_count := 0
const GRASS_SHADER := preload("res://shaders/grass.gdshader")
static var _grass_mat: ShaderMaterial

## Relva procedimental em MultiMesh por região (entra no culling por hemisfério).
func _build_turf() -> void:
	_turf_count = data.turf_dirs.size()
	if _turf_count == 0:
		return
	if _grass_mat == null:
		_grass_mat = ShaderMaterial.new()
		_grass_mat.shader = GRASS_SHADER
	var color: Color = PlanetGenerator.BIOMES[data.biome].palette.get("Grass", Color("5fb873"))
	var mesh := GrassTuft.mesh(color)
	var per_region: Array = []
	per_region.resize(_regions.size())
	for i in per_region.size():
		per_region[i] = []
	for i in _turf_count:
		per_region[_region_of(data.turf_dirs[i])].append(i)
	for r in _regions.size():
		var idxs: Array = per_region[r]
		if idxs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		mm.mesh = mesh
		mm.instance_count = idxs.size()
		for j in idxs.size():
			var k: int = idxs[j]
			var dir := data.turf_dirs[k]
			var b := SphereMath.basis_from_up(dir, data.turf_yaws[k]).scaled_local(Vector3.ONE * data.turf_sizes[k])
			mm.set_instance_transform(j, Transform3D(b, data.surface_point(dir) - dir * 0.03))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Turf"
		mmi.multimesh = mm
		mmi.material_override = _grass_mat
		# Relva densa só perto da câmara; mais longe vê-se a relva pintada no chão.
		mmi.visibility_range_end = TURF_VISIBLE_M + 20.0 # a região mede ~20 m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_regions[r].add_child(mmi)

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
		var dir := dirs[i]
		# Debaixo das peças de relevo o chão desce um pouco (a peça cobre-o).
		var sink := RELIEF_SINK if data.in_relief(dir) else 0.0
		verts[i] = dir * (data.radius + data.base_height_at(dir) - sink)
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
	terrain.material_override = _terrain_material()
	add_child(terrain)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

const RELIEF_SINK := 0.35
const RELIEF_SKIRT := 0.8 # m que a borda das peças desce para dentro do chão (sem frestas)
var relief_meshes: Array[MeshInstance3D] = []

## Peças de relevo: os triângulos da peça dobrados à curvatura (a altura da peça somada à do
## chão), topo com a cor do chão e paredes com a cor de rocha do bioma, uma saia na borda que
## entra no chão e colisão exata. Cada peça entra na região do seu centro (culling).
func _build_reliefs() -> void:
	relief_meshes.clear()
	if data.reliefs.is_empty():
		return
	var b: Dictionary = PlanetGenerator.BIOMES[data.biome]
	var top_col: Color = (b.ground as Color).lerp(b.palette.get("Grass", b.ground), 0.35)
	var rock_col: Color = b.palette.get("Rock", Color("c4bccf"))
	var i := 0
	for r in data.reliefs:
		var pc := ReliefKit.piece(r.kind)
		var tris: PackedVector3Array = pc.tris
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var cols := PackedColorArray()
		var center: Vector3 = r.dir
		for t in range(0, tris.size(), 3):
			var a := _relief_point(r, tris[t])
			var bb := _relief_point(r, tris[t + 1])
			var c := _relief_point(r, tris[t + 2])
			_relief_tri(verts, norms, cols, a, bb, c, top_col, rock_col, Vector3.ZERO)
		var border := ReliefKit.border_edges(pc)
		for e in range(0, border.size(), 2):
			var a := _relief_point(r, border[e])
			var bb := _relief_point(r, border[e + 1])
			var a2 := a - a.normalized() * RELIEF_SKIRT
			var b2 := bb - bb.normalized() * RELIEF_SKIRT
			var out := ((a + bb) * 0.5 - center * center.dot((a + bb) * 0.5)).normalized()
			_relief_tri(verts, norms, cols, a, bb, b2, top_col, rock_col, out)
			_relief_tri(verts, norms, cols, a, b2, a2, top_col, rock_col, out)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.name = "Relief%d" % i
		mi.mesh = mesh
		mi.material_override = CelShading.vertex_color_material(false)
		_regions[_region_of(center)].add_child(mi)
		relief_meshes.append(mi)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(verts)
		var cs := CollisionShape3D.new()
		cs.name = "Relief%d" % i
		cs.shape = shape
		body.add_child(cs)
		i += 1

## Vértice local da peça no espaço do planeta.
func _relief_point(r: Dictionary, v: Vector3) -> Vector3:
	var dir := data.relief_dir(r, v.x, v.z)
	return dir * (data.radius + data.base_height_at(dir) + v.y * float(r.height_scale))

## Triângulo com normal plana (visual low-poly); a saia fica virada para `out`. Cor: chão se a face estiver virada para cima, rocha nas paredes.
func _relief_tri(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		a: Vector3, b: Vector3, c: Vector3, top_col: Color, rock_col: Color, out: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	# A ordem da peça já vem certa do importador; só a saia precisa de ser virada.
	if out != Vector3.ZERO and n.dot(out) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var col := top_col if n.dot(a.normalized()) > 0.78 else rock_col
	verts.append_array([a, b, c])
	norms.append_array([n, n, n])
	cols.append_array([col, col, col])

const TERRAIN_SHADER := preload("res://shaders/terrain_grass.gdshader")
## Distância (m) até onde se desenha a relva procedimental (mais longe: a relva pintada no chão).
const TURF_VISIBLE_M := 34.0

## Chão com relva pintada (manchas e traços) nas cores do bioma.
func _terrain_material() -> ShaderMaterial:
	var b: Dictionary = PlanetGenerator.BIOMES[data.biome]
	var g: Color = b.ground
	var grass: Color = b.palette.get("Grass", g)
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("ground", g)
	m.set_shader_parameter("grass_dark", g.lerp(grass, 0.6).darkened(0.12))
	m.set_shader_parameter("grass_light", g.lerp(grass, 0.3).lightened(0.12))
	m.set_shader_parameter("strength", float(b.get("ground_grass", 1.0)))
	return m

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
		if info.get("recolor", "") != "":
			# Paleta em textura (relva mdvl): cor do bioma por vértice.
			var pal: Dictionary = PlanetGenerator.BIOMES[data.biome].palette
			mm.mesh = CelShading.recolor_textured_mesh(info.mesh, info.texture, pal[info.recolor])
			mmi.material_override = CelShading.vertex_color_material(with_outline)
		elif info.palette:
			# Pack de natureza: uma superfície com a cor da paleta do bioma por vértice.
			mm.mesh = CelShading.palette_mesh(info.mesh, PlanetGenerator.BIOMES[data.biome].palette)
			mmi.material_override = CelShading.vertex_color_material(with_outline)
		else:
			# Modelos do kit (paleta em textura): tom do bioma por cima.
			var biome_def: Dictionary = PlanetGenerator.BIOMES[data.biome]
			var tint: Color = biome_def.get("kit_tint", Color.WHITE)
			if info.has("tint_key"):
				tint = biome_def.palette[info.tint_key]
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
	# Casas dos colonos e base: edifícios montados com o pack modular sci-fi.
	for i in data.posts.size():
		var door: Vector3 = data.post_doors[i] if i < data.post_doors.size() else Vector3.ZERO
		var accent: Color = BuildingKit.COLONIST_ACCENTS[i % BuildingKit.COLONIST_ACCENTS.size()]
		_place_building(BuildingKit.colonist_house(), BuildingKit.palette_with_accent(accent), data.posts[i], "Post%d" % i, door)
	var plaza_face := data.toward_point(data.outpost_dir, data.post_doors[0], 1.0) if not data.post_doors.is_empty() else Vector3.ZERO
	_place_building(BuildingKit.outpost(), BuildingKit.BASE_PALETTE, data.outpost_dir, "Outpost", plaza_face)
	_place_model(LAIR_MODEL, data.lair_dir, 4.0, "Lair", data.lair_door)

## Edifício do pack modular, assente em `dir`, com a porta (+Z) virada para `face`.
func _place_building(parts: Array, palette: Dictionary, dir: Vector3, node_name: String, face: Vector3) -> Node3D:
	var b := BuildingKit.build(parts, palette)
	b.name = node_name
	add_child(b)
	b.transform = Transform3D(_facing_basis(dir, face), data.surface_point(dir) - dir * 0.05)
	return b

func _facing_basis(dir: Vector3, face: Vector3) -> Basis:
	var b := SphereMath.basis_from_up(dir)
	if face != Vector3.ZERO:
		var f := face - dir * face.dot(dir)
		if f.length() > 0.0001:
			var z := f.normalized()
			var x := dir.cross(z).normalized()
			b = Basis(x, dir, x.cross(dir)).orthonormalized()
	return b

## `face`: direção (espaço do planeta) para onde a frente (+Z) do modelo fica virada — a estrada.
func _place_model(kit_path: String, dir: Vector3, height: float, node_name: String, face := Vector3.ZERO) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	add_child(holder)
	var b := SphereMath.basis_from_up(dir)
	if face != Vector3.ZERO:
		var f := face - dir * face.dot(dir)
		if f.length() > 0.0001:
			var z := f.normalized()
			var x := dir.cross(z).normalized()
			b = Basis(x, dir, x.cross(dir)).orthonormalized()
	holder.transform = Transform3D(b, data.surface_point(dir))
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
