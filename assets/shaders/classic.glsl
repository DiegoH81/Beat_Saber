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


float get_cutoff(float depth)
{
	return depth / 24.0;
}

vec3 get_normal(vec2 in_uv)
{
    vec3 n = texture(normal_image, in_uv).rgb;
    return normalize(n * 2.0 - 1.0);
}


const float RADIUS = 4.0f;
const float NORMAL_THRESHOLD = 0.8f;

void main()
{
    vec2 size = parameters.raster_size;
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv_norm = uv/size;

    if (uv.x >= int(parameters.raster_size.x) || uv.y >= int(parameters.raster_size.y))
        return;
    
    vec4 color = imageLoad(color_image, uv);

    float depth = get_linear_depth(uv_norm);
    vec3 normal = get_normal(uv_norm);

    float depth_border = 1.0f;
    float normal_border = 1.0f;

    vec3 grayscale = vec3(color.r + color.g + color.b) / 3.0f;

    for (float x = -RADIUS; x <= RADIUS; x++)
    {
		for (float y = -RADIUS; y <= RADIUS; y++)
        {
			if (length(vec2(x, y)) > RADIUS)
				continue;

            vec2 offset_uv = uv_norm + vec2(x, y) / size;
            float offset_depth = get_linear_depth(offset_uv);
            
            if (abs(depth - offset_depth) > get_cutoff(min(depth, offset_depth)))
            {
				float dist = abs(depth - offset_depth) - get_cutoff(min(depth, offset_depth));
				depth_border = min(depth_border, max(0.0, 1.0 - dist * 0.5));
			}

            vec3 offset_normal = get_normal(offset_uv);
            float n_dot = dot(normal, offset_normal);
            if (n_dot < NORMAL_THRESHOLD)
            {
                float n_dist = (NORMAL_THRESHOLD - n_dot) / NORMAL_THRESHOLD;
                normal_border = min(normal_border, max(0.0, 1.0 - n_dist * 4.0));
            }
		}
	}

    float border = min(depth_border, normal_border);
    imageStore(color_image, uv, vec4(grayscale * border, 1.0));
}