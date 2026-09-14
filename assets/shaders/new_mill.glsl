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

const int   BLOCK_SIZE          = 6;
const float ABERRATION_STRENGTH = 4.0;
const float SCANLINE_FREQ       = 0.9;
const float SCANLINE_STRENGTH   = 0.18;
const float INTERLACE_STRENGTH  = 0.08;
const int   BLOOM_RADIUS        = 2;
const float BLOOM_THRESHOLD     = 0.65;
const float BLOOM_INTENSITY     = 0.8;
const float VIGNETTE_STRENGTH   = 0.35;

vec3 sample_block(ivec2 uv, vec2 size)
{
    ivec2 block_origin = (uv / BLOCK_SIZE) * BLOCK_SIZE;
    ivec2 block_center = clamp(block_origin + BLOCK_SIZE / 2, ivec2(0), ivec2(size) - 1);
    return imageLoad(color_image, block_center).rgb;
}

vec3 sample_with_aberration(ivec2 uv, vec2 size)
{
    vec2 center = size * 0.5;
    vec2 dir = (vec2(uv) - center) / max(size.x, size.y);
    vec2 offset = dir * ABERRATION_STRENGTH;

    ivec2 uv_r = ivec2(clamp(vec2(uv) + offset, vec2(0.0), size - 1.0));
    ivec2 uv_b = ivec2(clamp(vec2(uv) - offset, vec2(0.0), size - 1.0));

    return vec3(sample_block(uv_r, size).r, sample_block(uv, size).g, sample_block(uv_b, size).b);
}

void main()
{
    vec2 size = parameters.raster_size;
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    if (uv.x >= int(size.x) || uv.y >= int(size.y))
        return;

    vec3 color = sample_with_aberration(uv, size);

    vec3 bloom = vec3(0.0);
    float samples = 0.0;
    for (int x = -BLOOM_RADIUS; x <= BLOOM_RADIUS; x++)
    {
        for (int y = -BLOOM_RADIUS; y <= BLOOM_RADIUS; y++)
        {
            ivec2 offset_uv = clamp(uv + ivec2(x, y), ivec2(0), ivec2(size) - 1);
            vec3 neighbor = imageLoad(color_image, offset_uv).rgb;
            float luma = dot(neighbor, vec3(0.299, 0.587, 0.114));
            if (luma > BLOOM_THRESHOLD) { bloom += neighbor; samples += 1.0; }
        }
    }
    if (samples > 0.0)
        color += (bloom / samples) * BLOOM_INTENSITY;

    float scanline = sin(float(uv.y) * SCANLINE_FREQ) * 0.5 + 0.5;
    color *= mix(1.0, scanline, SCANLINE_STRENGTH);
    color *= mod(float(uv.y), 2.0) < 1.0 ? 1.0 : (1.0 - INTERLACE_STRENGTH);

    vec2 uv_norm = vec2(uv) / size;
    float dist = distance(uv_norm, vec2(0.5));
    color *= 1.0 - smoothstep(0.35, 0.75, dist) * VIGNETTE_STRENGTH;

    imageStore(color_image, uv, vec4(clamp(color, 0.0, 1.0), 1.0));
}