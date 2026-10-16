shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;

uniform float alpha : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = alpha;
}
