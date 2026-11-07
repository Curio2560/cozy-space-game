// Céu do espaço: cor de fundo, duas nebulosas (ruído) e estrelas. Cores por bioma.
shader_type sky;

uniform vec4 base_color : source_color = vec4(0.17, 0.13, 0.27, 1.0);
uniform vec4 nebula_a : source_color = vec4(0.45, 0.25, 0.6, 1.0);
uniform vec4 nebula_b : source_color = vec4(0.95, 0.5, 0.45, 1.0);
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.55;
uniform float star_density : hint_range(0.0, 0.2) = 0.06;
uniform float star_brightness : hint_range(0.0, 3.0) = 1.3;
uniform float brightness : hint_range(0.2, 2.0) = 1.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col = base_color.rgb;
	float n1 = fbm(d * 2.2);
	float n2 = fbm(d * 3.7 + vec3(5.2, 1.3, 7.7));
	col = mix(col, nebula_a.rgb, smoothstep(0.42, 0.8, n1) * nebula_strength);
	col = mix(col, nebula_b.rgb, smoothstep(0.5, 0.85, n2) * nebula_strength * 0.75);
	// Estrelas: células na esfera de direções; poucas acendem.
	vec3 g = d * 180.0;
	vec3 id = floor(g);
	float h = hash(id);
	if (h > 1.0 - star_density) {
		float r = length(fract(g) - 0.5);
		float twinkle = 0.75 + 0.25 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
		col += vec3(1.0, 0.95, 0.85) * (1.0 - smoothstep(0.05, 0.32, r)) * star_brightness * twinkle;
	}
	COLOR = col * brightness;
}
