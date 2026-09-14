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

const float SATURATION_BOOST   = 1.25;
const vec3  SHADOW_TONE        = vec3(0.03, 0.08, 0.16);
const vec3  HIGHLIGHT_TONE     = vec3(0.18, 0.05, 0.12);

const int   FLARE_SAMPLES      = 12;
const float FLARE_THRESHOLD    = 0.75;
const float FLARE_STRETCH      = 0.35;
const float FLARE_INTENSITY    = 0.5;
const vec3  FLARE_TINT         = vec3(1.0, 0.75, 0.9);

const float LEAK_WIDTH         = 0.4;
const vec3  LEAK_COLOR         = vec3(1.0, 0.5, 0.2);
const float LEAK_STRENGTH      = 0.3;

const float DUST_DENSITY       = 400.0;
const float DUST_STRENGTH      = 0.06;

const float VIGNETTE_STRENGTH  = 0.45;
const float FRAME_SOFTNESS     = 0.08;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

vec3 saturate_color(vec3 c, float amount)
{
    float luma = dot(c, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luma), c, amount);
}

void main()
{
    vec2 size = parameters.raster_size;
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    if (uv.x >= int(size.x) || uv.y >= int(size.y))
        return;

    vec2 uv_norm = vec2(uv) / size;
    vec3 c = imageLoad(color_image, uv).rgb;

    vec3 flare = vec3(0.0);
    float flare_samples = 0.0;
    for (int i = -FLARE_SAMPLES; i <= FLARE_SAMPLES; i++)
    {
        float t = float(i) * FLARE_STRETCH;
        ivec2 offset_uv = clamp(uv + ivec2(int(t), 0), ivec2(0), ivec2(size) - 1);
        vec3 neighbor = imageLoad(color_image, offset_uv).rgb;
        float luma = dot(neighbor, vec3(0.299, 0.587, 0.114));
        if (luma > FLARE_THRESHOLD)
        {
            float falloff = 1.0 - abs(float(i)) / float(FLARE_SAMPLES);
            flare += neighbor * falloff;
            flare_samples += 1.0;
        }
    }
    if (flare_samples > 0.0)
        c += (flare / flare_samples) * FLARE_TINT * FLARE_INTENSITY;

    
    float luma = dot(c, vec3(0.299, 0.587, 0.114));
    c += mix(SHADOW_TONE, HIGHLIGHT_TONE, luma);
    c = saturate_color(c, SATURATION_BOOST);

    float diag = (uv_norm.x + uv_norm.y) * 0.5;
    float leak = 1.0 - smoothstep(0.0, LEAK_WIDTH, abs(diag - 0.5));
    c += LEAK_COLOR * leak * LEAK_STRENGTH;

    float dust = hash(floor(vec2(uv) / 2.0));
    if (dust > 1.0 - (1.0 / DUST_DENSITY))
        c += DUST_STRENGTH;

    vec2 d = abs(uv_norm - 0.5) * 2.0;
    float frame = 1.0 - smoothstep(1.0 - FRAME_SOFTNESS, 1.0, max(d.x, d.y));
    c *= mix(1.0 - VIGNETTE_STRENGTH, 1.0, frame);

    imageStore(color_image, uv, vec4(clamp(c, 0.0, 1.0), 1.0));
}