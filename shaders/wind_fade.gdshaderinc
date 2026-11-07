// Partilhado por cel.gdshader e outline.gdshader (o contorno tem de acompanhar o modelo).
// - Vento: o modelo inclina-se mais quanto mais alto (VERTEX.y no espaço do modelo).
// - Ocultação: fragmentos entre a câmara e o jogador são cortados num padrão de pontos
//   (parece semitransparente, mas continua opaco: barato no renderer Compatibility).
uniform float wind_strength = 0.0;
uniform float wind_speed = 1.3;
uniform bool fade_occluder = false;
uniform vec3 occlude_from = vec3(0.0); // câmara (mundo)
uniform vec3 occlude_to = vec3(0.0); // jogador (mundo)
uniform float occlude_radius = 1.8;

varying vec3 wf_world;

// Devolve a posição no mundo (para guardar em wf_world dentro de vertex()).
vec3 wind_vertex(inout vec3 v, mat4 model, float t) {
	vec3 base = (model * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	if (wind_strength > 0.0) {
		float h = max(v.y, 0.0);
		float sway = sin(t * wind_speed + base.x * 0.21 + base.z * 0.17) + 0.4 * sin(t * wind_speed * 2.7 + base.y * 0.3);
		v.x += sway * wind_strength * h;
		v.z += sway * wind_strength * 0.6 * h;
	}
	return (model * vec4(v, 1.0)).xyz;
}

bool occluded(vec2 frag) {
	if (!fade_occluder) {
		return false;
	}
	vec3 ab = occlude_to - occlude_from;
	float len2 = dot(ab, ab);
	if (len2 < 0.01) {
		return false;
	}
	float t = clamp(dot(wf_world - occlude_from, ab) / len2, 0.0, 1.0);
	if (t < 0.03 || t > 0.92) {
		return false;
	}
	float d = length(occlude_from + ab * t - wf_world);
	if (d > occlude_radius) {
		return false;
	}
	// Dither 2×2: corta metade dos píxeis (mais perto do eixo, mais cortado).
	ivec2 p = ivec2(frag) % 2;
	float pattern = float(p.x + p.y * 2) / 4.0 + 0.125;
	return pattern < 0.75 * (1.0 - d / occlude_radius) + 0.25;
}
