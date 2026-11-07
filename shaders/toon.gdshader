// Toon / cel shader for Godot 4 — Mobile & Compatibility renderers.
// Two-tone lighting with a tinted shadow, optional rim light and hard specular.
shader_type spatial;
render_mode cull_back;

group_uniforms Color;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;

group_uniforms Shading;
// Colour multiplied into the dark side. A cool purple suits the Correio Cósmico palette.
uniform vec4 shadow_tint : source_color = vec4(0.55, 0.50, 0.78, 1.0);
// Where light turns to shadow (-1 = everything lit, 1 = everything dark).
uniform float shade_threshold : hint_range(-1.0, 1.0) = 0.05;
// 0 = razor-sharp edge. Small values avoid aliasing on phone screens.
uniform float shade_softness : hint_range(0.0, 0.5) = 0.03;
// Lets cast shadows (from other objects) also use the toon step.
uniform bool receive_shadows = true;

group_uniforms Rim;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.25;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;

group_uniforms Specular;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.0; // 0 = off (cheapest)
uniform float specular_size : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float shadow = receive_shadows ? ATTENUATION : 1.0;

	// Two-tone step
	float lit = smoothstep(shade_threshold - shade_softness,
						   shade_threshold + shade_softness,
						   n_dot_l * shadow);
	vec3 tone = mix(shadow_tint.rgb, vec3(1.0), lit);
	DIFFUSE_LIGHT += tone * LIGHT_COLOR / PI;

	// Rim light, only on the lit side
	if (rim_amount > 0.0) {
		float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim_edge = 1.0 - rim_width;
		float rim_mask = smoothstep(rim_edge - 0.02, rim_edge + 0.02, rim) * lit;
		SPECULAR_LIGHT += rim_color.rgb * rim_amount * rim_mask * LIGHT_COLOR / PI;
	}

	// Hard specular highlight
	if (specular_amount > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 64.0);
		float spec_cut = 1.0 - specular_size * 0.5;
		float spec_mask = smoothstep(spec_cut - 0.01, spec_cut + 0.01, spec) * lit;
		SPECULAR_LIGHT += vec3(specular_amount * spec_mask) * LIGHT_COLOR / PI;
	}
}
