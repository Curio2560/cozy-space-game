// Cel-shading do Correio Cósmico: rampa de 3 tons na luz difusa, brilho especular duro
// e rim light suave. A cor vem da paleta (atlas) dos modelos do kit.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_nearest, repeat_disable;
// Modelos com a cor da paleta guardada por vértice (pack de natureza, ver CelShading.palette_mesh).
uniform bool use_vertex_color = false;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
uniform vec4 albedo_tint : source_color = vec4(1.0);
// Limiares da rampa (em N·L) e luminosidade dos dois tons de sombra.
uniform float band_lit : hint_range(-1.0, 1.0) = 0.35;
uniform float band_mid : hint_range(-1.0, 1.0) = -0.05;
uniform float tone_mid : hint_range(0.0, 1.0) = 0.5;
uniform float tone_dark : hint_range(0.0, 1.0) = 0.24;
uniform float band_softness : hint_range(0.0, 0.2) = 0.03;
uniform float spec_size : hint_range(0.0, 1.0) = 0.006;
uniform float spec_strength : hint_range(0.0, 1.0) = 0.15;
uniform vec4 rim_color : source_color = vec4(1.0, 0.93, 0.85, 1.0);
uniform float rim_width : hint_range(0.0, 1.0) = 0.36;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo_tint;
	if (use_vertex_color) {
		c.rgb *= srgb_to_linear(COLOR.rgb);
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}

float ramp(float ndl) {
	float s = band_softness;
	float lit = smoothstep(band_lit - s, band_lit + s, ndl);
	float mid = smoothstep(band_mid - s, band_mid + s, ndl);
	return mix(tone_dark, mix(tone_mid, 1.0, lit), mid);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float shadow = ATTENUATION; // sombras projetadas contam como zona escura
	float tone = ramp(ndl * shadow + (shadow - 1.0));
	vec3 light_col = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += ALBEDO * light_col * tone;

	vec3 h = normalize(LIGHT + VIEW);
	float spec = step(1.0 - spec_size, dot(NORMAL, h)) * step(0.0, ndl) * shadow;
	SPECULAR_LIGHT += light_col * spec * spec_strength;

	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim_mask = smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.08, rim) * clamp(ndl + 0.3, 0.0, 1.0) * shadow;
	DIFFUSE_LIGHT += rim_color.rgb * light_col * rim_mask * rim_strength;
}
