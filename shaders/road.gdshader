// Estrada de terra batida: manchas de terra, pedrinhas e bermas irregulares que se misturam com
// o chão, e cel-shading igual ao terreno. (As marcas de rodas são deixadas pelo rover.)
// UV.x = de berma a berma (0..1); UV.y = metros ao longo da estrada.
shader_type spatial;
// Sem escrever profundidade: estradas sobrepostas (cruzamentos) fundem-se sem "piscar".
render_mode diffuse_lambert, specular_disabled, depth_draw_never;

uniform float band_lit = 0.35;
uniform float band_mid = -0.05;
uniform float tone_mid = 0.5;
uniform float tone_dark = 0.24;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(vec2(i, 3.1)), hash(vec2(i + 1.0, 3.1)), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	float side = step(0.5, UV.x);
	float edge = min(UV.x, 1.0 - UV.x); // 0 na berma, 0,5 no meio
	// Berma irregular: o limite varia ao longo da estrada (diferente de cada lado).
	float ragged = 0.03 + 0.11 * vnoise(UV.y * 0.55 + side * 17.0) + 0.04 * vnoise(UV.y * 2.3 + side * 5.0);
	if (edge < ragged) {
		discard;
	}
	vec3 c = COLOR.rgb;
	// Berma mais escura, a clarear para o meio.
	c *= mix(0.93, 1.0, smoothstep(ragged, ragged + 0.1, edge)); // suave: nos cruzamentos não se nota
	// Terra: manchas suaves (ruído de baixa frequência).
	float mottle = vnoise2(vec2(UV.x * 3.0, UV.y * 0.35)) * 0.6 + vnoise2(vec2(UV.x * 9.0, UV.y * 1.1)) * 0.4;
	c *= 0.9 + 0.2 * mottle;
	// Pedrinhas redondas espalhadas (uma por célula, nem todas as células têm).
	vec2 q = vec2(UV.x * 18.0, UV.y * 4.0);
	vec2 cell = floor(q);
	vec2 centre = vec2(hash(cell + 1.3), hash(cell + 4.1)) * 0.6 + 0.2;
	float r = 0.12 + 0.18 * hash(cell + 9.2);
	float dot_d = length((fract(q) - centre) * vec2(1.0, 1.0));
	float pebble = (1.0 - smoothstep(r * 0.8, r, dot_d)) * step(0.6, hash(cell + 2.7));
	c = mix(c, c * (hash(cell + 5.5) > 0.5 ? 1.22 : 0.8), pebble * 0.7);
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
