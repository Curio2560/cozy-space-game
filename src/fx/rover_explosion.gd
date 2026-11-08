class_name RoverExplosion
extends Node3D
## Explosão do rover, lenta e em 3D: clarão, bola de fogo em várias nuvens facetadas que
## crescem e escurecem, faúlhas, onda de choque, coluna de fumo e as rodas a voar como peças
## físicas. Desaparece sozinha ao fim de DURATION segundos.

const DURATION := 8.0
const FIRE_SHADER := preload("res://shaders/explosion_fire.gdshader")

var debris: Array[Debris] = []
var _t := 0.0
var _balls: Array = [] # [MeshInstance3D, ShaderMaterial, atraso, duração, posição inicial, deriva, escala máx.]
var _light: OmniLight3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _smoke: CPUParticles3D
var _up := Vector3.UP

## Começa a explosão em `pos` (global), com `up` = cima do planeta. Solta as rodas do rover.
func start(pos: Vector3, up: Vector3, planet_center: Vector3, rover: Rover = null) -> void:
	_up = up.normalized()
	global_transform = Transform3D(SphereMath.basis_from_up(_up), pos)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_make_light()
	_make_fireballs(rng)
	_make_ring()
	_make_embers()
	_make_smoke()
	if rover:
		_make_debris(rover, planet_center, rng)

func _make_light() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.light_energy = 9.0
	_light.omni_range = 22.0
	_light.position = Vector3(0, 1.5, 0)
	add_child(_light)

func _make_fireballs(rng: RandomNumberGenerator) -> void:
	for i in 9:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 10
		sm.rings = 6
		mi.mesh = sm
		var mat := ShaderMaterial.new()
		mat.shader = FIRE_SHADER
		mat.set_shader_parameter("seed", rng.randf() * 100.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var start := Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.3, 1.0), rng.randf_range(-0.7, 0.7))
		var drift := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(1.8, 4.5), rng.randf_range(-1.0, 1.0))
		mi.position = start
		mi.scale = Vector3.ONE * 0.2
		add_child(mi)
		_balls.append([mi, mat, i * 0.05 + rng.randf() * 0.1, rng.randf_range(2.8, 4.6), start, drift, rng.randf_range(3.5, 6.5)])

func _make_ring() -> void:
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	_ring.mesh = tm
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1.0, 0.85, 0.6, 0.8)
	_ring.material_override = _ring_mat
	_ring.position = Vector3(0, 0.15, 0)
	_ring.scale = Vector3(0.5, 0.15, 0.5)
	add_child(_ring)

func _particle_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	return m

func _make_embers() -> void:
	var p := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.12)
	box.material = _particle_material(Color.WHITE)
	p.mesh = box
	p.amount = 80
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 2.6
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 13.0
	p.gravity = -_up * 14.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	g.set_color(1, Color(0.6, 0.12, 0.05, 0.0))
	p.color_ramp = g
	p.position = Vector3(0, 0.8, 0)
	add_child(p)
	p.emitting = true

func _make_smoke() -> void:
	_smoke = CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.8
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = _particle_material(Color.WHITE)
	_smoke.mesh = sm
	_smoke.amount = 70
	_smoke.lifetime = 6.0
	_smoke.direction = Vector3.UP
	_smoke.spread = 18.0
	_smoke.initial_velocity_min = 1.6
	_smoke.initial_velocity_max = 3.2
	_smoke.gravity = _up * 0.35
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.9
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 4.5))
	_smoke.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(0.32, 0.27, 0.27, 0.95))
	g.set_color(1, Color(0.22, 0.2, 0.24, 0.0))
	_smoke.color_ramp = g
	_smoke.position = Vector3(0, 1.0, 0)
	add_child(_smoke)
	_smoke.emitting = true

func _make_debris(rover: Rover, center: Vector3, rng: RandomNumberGenerator) -> void:
	for w in rover.detach_wheels():
		var body := Debris.new()
		body.planet_center = center
		body.mass = 12.0
		var mi := MeshInstance3D.new()
		mi.mesh = (w[0] as MeshInstance3D).mesh
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, (w[0] as MeshInstance3D).get_active_material(i))
		mi.material_overlay = (w[0] as MeshInstance3D).material_overlay
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = rover.wheel_radius
		cs.shape = sph
		body.add_child(cs)
		body.collision_layer = 0
		body.collision_mask = 1
		get_parent().add_child(body)
		body.global_transform = w[1]
		var out: Vector3 = ((w[1] as Transform3D).origin - global_position).normalized()
		body.linear_velocity = (out * rng.randf_range(4.0, 7.0) + _up * rng.randf_range(7.0, 11.0))
		body.angular_velocity = Vector3(rng.randf_range(-12, 12), rng.randf_range(-12, 12), rng.randf_range(-12, 12))
		debris.append(body)

func _process(delta: float) -> void:
	_t += delta
	for b in _balls:
		var local_t: float = (_t - b[2]) / b[3]
		var mi: MeshInstance3D = b[0]
		if local_t < 0.0:
			mi.visible = false
			continue
		mi.visible = local_t < 1.0
		var life := clampf(local_t, 0.0, 1.0)
		var grow := 1.0 - pow(1.0 - minf(life * 3.0, 1.0), 3.0) # rebenta depressa e abranda
		mi.scale = Vector3.ONE * lerpf(1.0, b[6], grow)
		mi.position = (b[4] as Vector3) + (b[5] as Vector3) * life
		(b[1] as ShaderMaterial).set_shader_parameter("life", life)
	if _light:
		_light.light_energy = 9.0 * maxf(0.0, 1.0 - _t / 1.6)
	if _ring:
		var rt := clampf(_t / 0.9, 0.0, 1.0)
		var r := lerpf(0.5, 9.0, 1.0 - pow(1.0 - rt, 2.0))
		_ring.scale = Vector3(r, 0.15, r)
		_ring_mat.albedo_color.a = 0.8 * (1.0 - rt)
	if _smoke and _t > 5.0:
		_smoke.emitting = false
	if _t > DURATION:
		for d in debris:
			if is_instance_valid(d):
				d.queue_free()
		queue_free()
