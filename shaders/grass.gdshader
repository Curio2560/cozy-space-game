// Relva (tufos procedimentais): cor por vértice (base escura, ponta clara), cel-shading como o
// terreno, as duas faces visíveis e ondulação com o vento (mais forte nas pontas).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform float band_lit = 0.35;
uniform float band_mid = -0.05;
uniform float tone_mid = 0.62;
uniform float tone_dark = 0.4;
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.6;

varying vec3 up_view;


void vertex() {
	// "Cima" do tufo em espaço de vista (MODELVIEW inclui a transformação da instância).
	up_view = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	// COLOR.a = altura relativa na folha (0 na base, 1 na ponta).
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * wind_speed + world.x * 0.35 + world.z * 0.27) + 0.5 * sin(TIME * wind_speed * 2.3 + world.y * 0.5);
	VERTEX.x += sway * wind_strength * COLOR.a;
	VERTEX.z += sway * wind_strength * 0.6 * COLOR.a;
}

void fragment() {
	// Normal sempre "para cima" do tufo (as duas faces iguais, tons como o chão).
	NORMAL = normalize(up_view);
	ALBEDO = COLOR.rgb; // o Godot já entrega COLOR em linear
	ROUGHNESS = 1.0;
}

void light() {
	// A normal da relva aponta para cima (como o chão): tons iguais aos do terreno.
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = step(band_lit, ndl);
	float mid = step(band_mid, ndl);
	float tone = mix(tone_dark, mix(tone_mid, 1.0, lit), mid);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * tone;
}
