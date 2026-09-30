shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 1.0;

varying vec3 local_pos;

void vertex()
{
    local_pos = VERTEX;
}

void fragment()
{
    float angle = atan(local_pos.z, local_pos.x);
    float normalized_angle = (angle + PI) / TAU;

    if (normalized_angle > progress)
        discard;

    ALBEDO = color.rgb;
    EMISSION = color.rgb * emission_energy;
    ALPHA = color.a;
}