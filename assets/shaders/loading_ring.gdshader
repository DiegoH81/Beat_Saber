shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float inner_radius = 0.35;
uniform float outer_radius = 0.5;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);

	float a = atan(p.x, -p.y);
	if (a < 0.0) a += TAU;
	a /= TAU;

	float ring = step(inner_radius, r) * step(r, outer_radius);
	float fill = step(a, progress);

	ALBEDO = ring_color.rgb;
	ALPHA = ring * fill * ring_color.a;
}