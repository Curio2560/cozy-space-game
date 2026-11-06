// Contorno por inverted hull: segundo passe com as faces da frente cortadas e os vértices
// empurrados pela normal. Cor = cor do objeto (paleta) escurecida.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform float width : hint_range(0.0, 0.2) = 0.032; // metros, à escala do mundo
uniform float darkness : hint_range(0.0, 1.0) = 0.22;
// true quando a malha foi preparada por CelShading.outline_ready_mesh (normal suave na tangente).
uniform bool use_tangent_normals = false;

void vertex() {
	// Compensa a escala do nó para o contorno ter espessura constante no mundo.
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 n = use_tangent_normals ? normalize(TANGENT) : normalize(NORMAL);
	VERTEX += n * width / max(s, 0.0001);
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * darkness;
}
