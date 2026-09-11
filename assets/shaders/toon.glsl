#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(push_constant) uniform push_constants {
    mat4 inv_proj_mat;
	vec2 raster_size;
} parameters;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D depth_image;
layout(set = 0, binding = 2) uniform sampler2D normal_image;

const float BANDS = 4.0;
const float SMOOTHNESS = 0.05;

vec3 get_view_position(vec2 in_uv)
{
    float raw_depth = texture(depth_image, in_uv).r;
    vec3 ndc = vec3(in_uv * 2.0f - 1.0f, raw_depth);
    vec4 view = parameters.inv_proj_mat * vec4(ndc, 1.0);
    view.xyz /= view.w;

    return view.xyz;
}

float get_linear_depth(vec2 in_uv)
{
    return -get_view_position(in_uv).z;
}

vec3 posterize_color(vec3 color, float bands, float smoothness)
{
    vec3 scaled = color * bands;
    vec3 lower = floor(scaled);
    vec3 frac = scaled - lower;

    float edge = clamp(smoothness, 0.001, 0.499);
    vec3 blend = smoothstep(0.5 - edge, 0.5 + edge, frac);

    vec3 result = (lower + blend) / bands;
    return clamp(result, 0.0, 1.0);
}

void main()
{
    vec2 size = parameters.raster_size;
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    if (uv.x >= int(parameters.raster_size.x) || uv.y >= int(parameters.raster_size.y))
        return;

    vec4 color = imageLoad(color_image, uv);

    vec3 posterized = posterize_color(color.rgb, BANDS, SMOOTHNESS);

    imageStore(color_image, uv, vec4(posterized, color.a));
}