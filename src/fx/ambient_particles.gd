class_name AmbientParticles
extends CPUParticles3D
## Partículas ambiente à volta da câmara, por bioma: pólen a flutuar no prado, bolhas a
## subir no ácido, faúlhas na lava. Segue um alvo e alinha-se com o "cima" do planeta.

const STYLES := {
	"prado": {"color": Color(1.0, 0.95, 0.6, 0.85), "size": 0.06, "rise": 0.15, "drift": 0.35, "amount": 70, "glow": false},
	"acido": {"color": Color(0.7, 1.0, 0.35, 0.7), "size": 0.12, "rise": 0.6, "drift": 0.1, "amount": 50, "glow": true},
	"lava": {"color": Color(1.0, 0.55, 0.15, 0.95), "size": 0.07, "rise": 1.2, "drift": 0.5, "amount": 80, "glow": true},
	"gelo": {"color": Color(1.0, 1.0, 1.0, 0.9), "size": 0.06, "rise": -0.5, "drift": 0.4, "amount": 90, "glow": false},
}
const BOX := Vector3(16.0, 5.0, 16.0)

var planet_center := Vector3.ZERO
var target: Node3D
var biome := ""

func setup(p_biome: String) -> void:
	biome = p_biome
	var st: Dictionary = STYLES.get(biome, STYLES.prado)
	var sm := SphereMesh.new()
	sm.radius = st.size
	sm.height = st.size * 2.0
	sm.radial_segments = 4
	sm.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if st.glow:
		mat.emission_enabled = true
		mat.emission = (st.color as Color)
	sm.material = mat
	mesh = sm
	amount = st.amount
	lifetime = 6.0
	preprocess = 6.0
	local_coords = false
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = BOX * 0.5
	spread = 180.0
	initial_velocity_min = 0.0
	initial_velocity_max = st.drift
	var g := Gradient.new()
	var c: Color = st.color
	g.set_color(0, Color(c.r, c.g, c.b, 0.0))
	g.add_point(0.2, c)
	g.add_point(0.8, c)
	g.set_color(g.get_point_count() - 1, Color(c.r, c.g, c.b, 0.0))
	color_ramp = g
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitting = true

func _process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var up := (target.global_position - planet_center).normalized()
	global_transform = Transform3D(SphereMath.basis_from_up(up), target.global_position + up * (BOX.y * 0.5 - 0.5))
	var st: Dictionary = STYLES.get(biome, STYLES.prado)
	gravity = up * float(st.rise) * 0.3
