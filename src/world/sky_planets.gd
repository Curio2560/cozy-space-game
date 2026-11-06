class_name SkyPlanets
extends Node3D
## Planetas em pixel-art (Tiny Planet Pack) a rodar suavemente no céu. Segue a posição da câmara (como
## uma skybox), mas não a rotação: ao andar à volta do planeta eles nascem e põem-se.

const DIR := "res://assets/sky/planets/"
const FRAMES := 6
const DISTANCE := 420.0

const SHADER := preload("res://shaders/sky_planet.gdshader")

var _quads: Array[MeshInstance3D] = []

## `planets`: [{tex: "planeta_ciano", dir: Vector3, size: float (graus), tint: Color, fps: float}]
## Cada planeta é um quad com um shader que mistura fotogramas (rotação suave).
func setup(planets: Array) -> void:
	for q in _quads:
		q.queue_free()
	_quads.clear()
	var i := 0
	for p in planets:
		var sheet: Texture2D = load(DIR + p.tex + ".png")
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("sheet", sheet)
		mat.set_shader_parameter("frames", float(FRAMES))
		mat.set_shader_parameter("fps", float(p.get("fps", 1.5)) * 0.5) # mais lento e contínuo
		mat.set_shader_parameter("phase", float(i) * 1.7)
		mat.set_shader_parameter("tint", p.get("tint", Color.WHITE))
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var world := 2.0 * DISTANCE * tan(deg_to_rad(float(p.size)) * 0.5)
		quad.size = Vector2(world, world)
		q.mesh = quad
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = (p.dir as Vector3).normalized() * DISTANCE
		q.extra_cull_margin = world
		add_child(q)
		_quads.append(q)
		i += 1

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position

func count() -> int:
	return _quads.size()
