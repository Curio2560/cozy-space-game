// Planeta do céu em 3D: esfera com o mapa-mundo (gerado de tools/planet_maps.gd) a rodar.
// Luz de uma estrela fixa (lado de dia e de noite com terminador suave) e orla de atmosfera.
// Sem luzes da cena: os planetas do céu não mudam com o sol do jogador.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform sampler2D map : source_color, filter_nearest, repeat_enable;
uniform vec3 light_dir = vec3(0.6, 0.45, 0.65); // de onde vem a luz (mundo)
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 atmosphere : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float night = 0.12; // luminosidade do lado da noite

varying vec3 n_world;

void vertex() {
	n_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = texture(map, UV).rgb * tint.rgb;
	vec3 l = normalize(light_dir);
	float ndl = dot(normalize(n_world), l);
	// Terminador suave e em poucos tons (fica a condizer com o cel-shading).
	float lit = smoothstep(-0.08, 0.25, ndl);
	lit = floor(lit * 4.0 + 0.5) / 4.0;
	vec3 shaded = col * mix(night, 1.05, lit);
	// Orla de atmosfera: mais forte na borda e do lado iluminado.
	vec3 v = normalize(VIEW);
	float rim = pow(1.0 - clamp(dot(NORMAL, v), 0.0, 1.0), 3.0);
	shaded += atmosphere.rgb * rim * (0.25 + 0.75 * clamp(ndl + 0.3, 0.0, 1.0)) * 0.8;
	ALBEDO = shaded;
}
