shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

void fragment()
{
	float flow = 0.5 + 0.5 * sin(UV.y * 64.0 + UV.x * 12.566 + TIME * 16.0);
	float streak = pow(flow, 5.0);
	float ends = smoothstep(0.0, 0.1, UV.y) * (1.0 - smoothstep(0.93, 1.0, UV.y));
	float facing = pow(max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.0);
	ALBEDO = vec3(1.0, 0.21, 0.48);
	EMISSION = vec3(1.0, 0.13, 0.36) * (1.4 + streak * 2.2);
	ALPHA = ends * facing * (0.20 + streak * 0.21);
}
