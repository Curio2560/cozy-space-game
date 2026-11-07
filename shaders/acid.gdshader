// Rio de ácido: verde néon com ondulação a correr, bolhinhas e margens mais escuras.
// UV.x = de margem a margem (0..1); UV.y = metros ao longo do rio.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

uniform vec4 acid : source_color = vec4(0.55, 1.0, 0.23, 1.0);
uniform vec4 deep : source_color = vec4(0.18, 0.55, 0.12, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0; // 0 no meio, 1 na margem
	float flow = UV.y - TIME * 0.8;
	float wave = sin(flow * 2.2 + UV.x * 6.0) * 0.5 + 0.5;
	float ripple = step(0.82, wave) * (1.0 - across);
	// Bolhinhas: células que acendem e apagam.
	vec2 cell = floor(vec2(UV.x * 6.0, flow * 1.5));
	float h = hash(cell);
	float pop = step(0.93, h) * step(0.5, fract(TIME * 0.7 + h * 5.0));
	vec3 col = mix(acid.rgb, deep.rgb, smoothstep(0.55, 1.0, across));
	col = mix(col, vec3(0.92, 1.0, 0.75), max(ripple * 0.6, pop * 0.8));
	ALBEDO = col;
}
