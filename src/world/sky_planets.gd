class_name SkyPlanets
extends Node3D
## Planetas em pixel-art (Tiny Planet Pack) a rodar no céu. Segue a posição da câmara (como
## uma skybox), mas não a rotação: ao andar à volta do planeta eles nascem e põem-se.

const DIR := "res://assets/sky/planets/"
const FRAMES := 6
const DISTANCE := 420.0

var _sprites: Array[Sprite3D] = []
var _textures: Array = [] # [Array[AtlasTexture]]
var _frame_time := 0.0
var _fps: Array[float] = []

## `planets`: [{tex: "planeta_ciano", dir: Vector3, size: float (graus), tint: Color, fps: float}]
func setup(planets: Array) -> void:
	for s in _sprites:
		s.queue_free()
	_sprites.clear()
	_textures.clear()
	_fps.clear()
	for p in planets:
		var sheet: Texture2D = load(DIR + p.tex + ".png")
		var frames: Array[AtlasTexture] = []
		var w := sheet.get_width() / FRAMES
		for i in FRAMES:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * w, 0, w, sheet.get_height())
			frames.append(at)
		var s := Sprite3D.new()
		s.texture = frames[0]
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.modulate = p.get("tint", Color.WHITE)
		var dir: Vector3 = (p.dir as Vector3).normalized()
		s.position = dir * DISTANCE
		# Tamanho angular em graus -> tamanho no mundo à distância DISTANCE.
		var world := 2.0 * DISTANCE * tan(deg_to_rad(float(p.size)) * 0.5)
		s.pixel_size = world / w
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		_sprites.append(s)
		_textures.append(frames)
		_fps.append(float(p.get("fps", 1.5)))

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position
	_frame_time += delta
	for i in _sprites.size():
		var frames: Array = _textures[i]
		_sprites[i].texture = frames[int(_frame_time * _fps[i]) % FRAMES]

func count() -> int:
	return _sprites.size()
