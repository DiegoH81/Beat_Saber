shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

group_uniforms TintFilter;
uniform vec3 tint_color : source_color = vec3(0.8, 0.1, 0.9);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.35;
uniform float overall_alpha : hint_range(0.0, 1.0) = 0.85;

group_uniforms ScanBars;
uniform float bar_count : hint_range(5.0, 300.0) = 60.0;
uniform float bar_speed : hint_range(-20.0, 20.0) = 6.0;
uniform float bar_width : hint_range(0.0, 1.0) = 0.15;
uniform float bar_darkness : hint_range(0.0, 1.0) = 0.6;

void fragment() {
    vec2 screen_uv = SCREEN_UV;
    vec3 background = texture(screen_texture, screen_uv).rgb;

    vec3 tinted = mix(background, tint_color, tint_strength);

    float line_pos = fract(UV.y * bar_count + TIME * bar_speed);
    float bar = step(line_pos, bar_width);
    vec3 with_bars = mix(tinted, tinted * (1.0 - bar_darkness), bar);

    ALBEDO = with_bars;
    ALPHA = overall_alpha;
}