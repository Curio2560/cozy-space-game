// Planeta do céu (folha de fotogramas em fila): mistura cada fotograma com o seguinte para a
// rotação ficar suave mesmo com poucos fotogramas. Sempre virado para a câmara (billboard).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform sampler2D sheet : source_color, filter_nearest, repeat_disable;
uniform float frames = 6.0;
uniform float fps = 1.5;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void vertex() {
	// Billboard: mantém a escala do nó, alinha com a câmara.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

vec4 frame_at(float f, vec2 uv) {
	return texture(sheet, vec2((mod(f, frames) + uv.x) / frames, uv.y));
}

void fragment() {
	float t = TIME * fps + phase;
	float f0 = floor(t);
	float k = smoothstep(0.0, 1.0, fract(t));
	vec4 a = frame_at(f0, UV);
	vec4 b = frame_at(f0 + 1.0, UV);
	vec4 c = mix(a, b, k);
	if (max(a.a, b.a) < 0.5) {
		discard;
	}
	ALBEDO = c.rgb / max(c.a, 0.001) * tint.rgb;
}
