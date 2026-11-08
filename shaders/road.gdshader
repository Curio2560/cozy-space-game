// Estrada de terra cartoon (textura assets/terrain/road/dirt.png): sulcos escuros das rodas,
// meio mais claro, berma orgânica e mais escura a fundir-se com a relva. Cel-shading igual
// ao terreno. Também usado nas manchas de terra.
// UV.x = de berma a berma (0..1; nas manchas 0 na borda, 0,5 no centro); UV.y = metros ao
// longo. UV2 = metros no plano da estrada/mancha (para a textura não esticar).
// COLOR.rgb = tom do bioma (multiplica a textura); COLOR.a = 1 nas estradas com sulcos.
shader_type spatial;
// Sem escrever profundidade: estradas sobrepostas (cruzamentos) fundem-se sem "piscar".
render_mode diffuse_lambert, specular_disabled, depth_draw_never;

uniform sampler2D dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile_m = 6.5;
uniform float brightness = 1.15;
uniform float saturation = 0.62; // a textura é muito laranja; no jogo fica mais terrosa // a rampa de luz cel escurece; compensar para a terra ficar clara
uniform float band_lit = 0.35;
uniform float band_mid = -0.05;
uniform float tone_mid = 0.5;
uniform float tone_dark = 0.24;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(vec2(i, 3.1)), hash(vec2(i + 1.0, 3.1)), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	float side = step(0.5, UV.x);
	float edge = min(UV.x, 1.0 - UV.x); // 0 na berma, 0,5 no meio
	// Berma orgânica: ondula devagar ao longo da estrada (lóbulos largos, não "papel rasgado").
	float ragged = 0.02 + 0.07 * vnoise(UV.y * 0.25 + side * 17.0) + 0.025 * vnoise(UV.y * 0.9 + side * 5.0);
	if (edge < ragged) {
		discard;
	}
	vec3 t = texture(dirt, UV2 / tile_m).rgb;
	t = mix(vec3(dot(t, vec3(0.299, 0.587, 0.114))), t, saturation);
	vec3 c = t * COLOR.rgb * brightness;
	// Berma mais escura e húmida, a clarear para dentro.
	float inner = smoothstep(ragged, ragged + 0.09, edge);
	c *= mix(0.72, 1.0, inner);
	if (COLOR.a > 0.5) {
		// Sulcos das rodas: duas faixas escuras com riscos ao longo; o meio fica mais claro.
		float x = UV.x;
		float rut = max(1.0 - smoothstep(0.0, 0.085, abs(x - 0.3)), 1.0 - smoothstep(0.0, 0.085, abs(x - 0.7)));
		float streak = 0.55 + 0.45 * vnoise(x * 70.0 + floor(UV.y * 0.6) * 13.0);
		c *= 1.0 - rut * 0.28 * streak;
		float hump = 1.0 - smoothstep(0.0, 0.12, abs(x - 0.5));
		c *= 1.0 + hump * 0.07;
	}
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
