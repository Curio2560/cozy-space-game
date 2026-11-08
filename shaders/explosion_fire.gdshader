// Nuvem da explosão: esfera facetada inflada com ruído, cor do núcleo branco-amarelo para
// laranja, vermelho e fumo escuro conforme a vida; bordas mais escuras (fresnel) para dar volume.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;

uniform float life = 0.0; // 0 = nasce, 1 = desaparece
uniform float seed = 0.0;
uniform vec4 hot : source_color = vec4(1.0, 0.97, 0.75, 1.0);
uniform vec4 fire : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 ember : source_color = vec4(0.75, 0.16, 0.08, 1.0);
uniform vec4 smoke : source_color = vec4(0.16, 0.13, 0.15, 1.0);

float h(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719)) + seed) * 43758.5453);
}

void vertex() {
	// Bolhas: cada vértice sai mais ou menos, e borbulha com o tempo.
	float n = h(floor(VERTEX * 3.0));
	VERTEX += NORMAL * (n - 0.5) * 0.35 * (0.6 + life);
}

void fragment() {
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c;
	if (life < 0.15) {
		c = mix(hot.rgb, fire.rgb, life / 0.15);
	} else if (life < 0.45) {
		c = mix(fire.rgb, ember.rgb, (life - 0.15) / 0.3);
	} else {
		c = mix(ember.rgb, smoke.rgb, clamp((life - 0.45) / 0.3, 0.0, 1.0));
	}
	// Bordas mais escuras e o centro mais quente: volume.
	c = mix(c, c * 0.45, smoothstep(0.35, 1.0, fres));
	ALBEDO = c;
	ALPHA = (1.0 - smoothstep(0.65, 1.0, life)) * (1.0 - smoothstep(0.85, 1.0, fres) * 0.6);
}
