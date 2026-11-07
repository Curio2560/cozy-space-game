// Terreno com "relva pintada": manchas suaves e traços de erva (ruído no espaço do mundo, sem
// textura) por cima da cor do chão, e cel-shading com bandas nítidas como o resto do terreno.
// Dá a sensação de relva cheia ao longe, onde já não se desenham tufos.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 ground : source_color = vec4(0.56, 0.83, 0.63, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.36, 0.66, 0.45, 1.0);
uniform vec4 grass_light : source_color = vec4(0.7, 0.9, 0.62, 1.0);
uniform float strength = 1.0; // 0 = chão liso (biomas sem relva)
uniform float band_lit = 0.35;
uniform float band_mid = -0.05;
uniform float tone_mid = 0.5;
uniform float tone_dark = 0.24;

varying vec3 wpos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = VERTEX; // espaço do planeta
}

void fragment() {
	vec3 c = ground.rgb;
	// Manchas grandes de relva mais escura/clara.
	float patches = vnoise(wpos * 0.12) * 0.6 + vnoise(wpos * 0.35) * 0.4;
	c = mix(c, grass_dark.rgb, smoothstep(0.55, 0.8, patches) * 0.55 * strength);
	c = mix(c, grass_light.rgb, smoothstep(0.45, 0.2, patches) * 0.35 * strength);
	// Traços de erva: células pequenas, alongadas, umas mais escuras outras mais claras.
	vec3 q = wpos * vec3(3.2, 1.2, 3.2);
	float h = hash(floor(q));
	float blade = step(0.62, h) * (1.0 - smoothstep(0.0, 0.5, length(fract(q.xz) - 0.5)));
	c = mix(c, (h > 0.81 ? grass_light.rgb : grass_dark.rgb), blade * 0.5 * strength);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = smoothstep(band_lit - 0.004, band_lit + 0.004, ndl);
	float mid = smoothstep(band_mid - 0.004, band_mid + 0.004, ndl);
	float tone = mix(tone_dark, mix(tone_mid, 1.0, lit), mid);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * tone;
}
