// Inverted-hull outline for Godot 4. Use as the Next Pass of toon.gdshader.
// Width is in screen pixels, so it stays constant at any distance (good for mobile).
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.07, 0.06, 0.16, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 clip_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;

	if (length(clip_normal) > 0.0001) {
		vec2 offset = normalize(clip_normal) / VIEWPORT_SIZE * outline_width * 2.0;
		clip.xy += offset * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
