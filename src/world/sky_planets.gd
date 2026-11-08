class_name SkyPlanets
extends Node3D
## Planetas do céu em 3D (mapas do Tiny Planet Pack) a rodar suavemente. Segue a posição da câmara (como
## uma skybox), mas não a rotação: ao andar à volta do planeta eles nascem e põem-se.

const DIR := "res://assets/sky/planets/"
const FRAMES := 6
const DISTANCE := 420.0

const SHADER := preload("res://shaders/sky_planet.gdshader")

var _quads: Array[MeshInstance3D] = []

## `planets`: [{tex: "planeta_ciano", dir: Vector3, size: float (graus), tint: Color, fps: float}]
## Cada planeta é uma esfera com o mapa-mundo `<tex>_map.png` (ver tools/planet_maps.gd) a rodar
## à volta de um eixo inclinado. `fps` (dos fotogramas antigos) dá a velocidade de rotação.
func setup(planets: Array) -> void:
	for q in _quads:
		q.queue_free()
	_quads.clear()
	_spin.clear()
	_axis.clear()
	var i := 0
	for p in planets:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		var map: Texture2D = load(DIR + p.tex + "_map.png")
		mat.set_shader_parameter("map", map)
		mat.set_shader_parameter("tint", p.get("tint", Color.WHITE))
		mat.set_shader_parameter("atmosphere", _average(map).lightened(0.35))
		mat.set_shader_parameter("light_dir", LIGHT_DIR)
		var q := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var world := 2.0 * DISTANCE * tan(deg_to_rad(float(p.size)) * 0.5)
		sphere.radius = world * 0.5
		sphere.height = world
		sphere.radial_segments = 48
		sphere.rings = 24
		q.mesh = sphere
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = (p.dir as Vector3).normalized() * DISTANCE
		q.extra_cull_margin = world
		# Eixo inclinado diferente para cada planeta e fase inicial.
		var axis := Vector3(sin(i * 2.1) * 0.35, 1.0, cos(i * 1.3) * 0.25).normalized()
		q.basis = Basis(Quaternion(Vector3.UP, axis)) # o polo do mapa fica no eixo
		q.rotate(axis, i * 1.7)
		add_child(q)
		_quads.append(q)
		_axis.append(axis)
		# Uma volta completa em 6 fotogramas / fps segundos (como antes), mais devagar.
		_spin.append(TAU * float(p.get("fps", 1.5)) * 0.5 / FRAMES)
		i += 1

const LIGHT_DIR := Vector3(0.6, 0.45, 0.65)
var _spin: Array[float] = []
var _axis: Array[Vector3] = []

static func _average(tex: Texture2D) -> Color:
	var img := tex.get_image()
	if img == null:
		return Color.WHITE
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	return img.get_pixel(0, 0)

## Velocidade de rotação (rad/s) do planeta `i`.
func spin_speed(i: int) -> float:
	return _spin[i]

func _process(delta: float) -> void:
	for i in _quads.size():
		_quads[i].rotate(_axis[i], _spin[i] * delta)
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position

func count() -> int:
	return _quads.size()
