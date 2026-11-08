// Contorno por inverted hull: segundo passe com as faces da frente cortadas e os vértices
// empurrados pela normal. Cor = cor do objeto (paleta) escurecida.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_nearest, repeat_disable;
// Modelos com a cor da paleta guardada por vértice (pack de natureza, ver CelShading.palette_mesh).
uniform bool use_vertex_color = false;
#include "res://shaders/wind_fade.gdshaderinc"

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
uniform float width : hint_range(0.0, 0.2) = 0.032; // metros, à escala do mundo
uniform float darkness : hint_range(0.0, 1.0) = 0.22;
// true quando a malha foi preparada por CelShading.outline_ready_mesh (normal suave na tangente).
uniform bool use_tangent_normals = false;

void vertex() {
	wf_world = wind_vertex(VERTEX, MODEL_MATRIX, TIME);
	// Compensa a escala do nó para o contorno ter espessura constante no mundo.
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 n = use_tangent_normals ? normalize(TANGENT) : normalize(NORMAL);
	VERTEX += n * width / max(s, 0.0001);
}

void fragment() {
#ifdef USE_FADE
	if (occluded(FRAGCOORD.xy)) {
		discard;
	}
#endif
	vec3 c = texture(albedo_tex, UV).rgb;
	if (use_vertex_color) {
		c *= COLOR.rgb; // o Godot já entrega COLOR em linear
	}
	ALBEDO = c * darkness;
}
