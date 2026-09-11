@tool
extends CompositorEffect
class_name MyEffects

const DEFAULT_SHADER_PATH := "res://assets/shaders/classic.glsl"

var rd := RenderingServer.get_rendering_device()
var shader: RID
var pipeline: RID
var depth_sampler: RID

func _init(glsl_path: String = DEFAULT_SHADER_PATH) -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	needs_normal_roughness = true
	
	var shader_file: RDShaderFile = load(glsl_path)
	if not shader_file:
		return

	var shader_spiriv := shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spiriv)
	pipeline = rd.compute_pipeline_create(shader)

	depth_sampler = rd.sampler_create(RDSamplerState.new())
	
func _render_callback(effect_callback_type: int, render_data: RenderData) -> void:
	var render_scene_buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	var size := render_scene_buffers.get_internal_size()
	
	# Get camera proj
	var inv_proj_mat := render_data.get_render_scene_data().get_cam_projection().inverse()
	#print(inv_proj_mat)
	var inv_proj_mat_array := PackedVector4Array([inv_proj_mat.x, inv_proj_mat.y, inv_proj_mat.z, inv_proj_mat.w])
	var raster_size := PackedFloat32Array([size.x, size.y])

	var push_constants := inv_proj_mat_array.to_byte_array()
	push_constants.append_array(raster_size.to_byte_array())
	
	
	# Color - 0
	var color_layer_uniform := RDUniform.new()
	color_layer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color_layer_uniform.binding = 0
	color_layer_uniform.add_id(render_scene_buffers.get_color_layer(0))

	# Depth - 1
	var depth_layer_uniform := RDUniform.new()
	depth_layer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	depth_layer_uniform.binding = 1
	depth_layer_uniform.add_id(depth_sampler)
	depth_layer_uniform.add_id(render_scene_buffers.get_depth_layer(0))

	# Normal
	var context_name := "forward_clustered"
	var normal_roughness_rid := render_scene_buffers.get_texture(context_name, "normal_roughness")
	var normal_layer_uniform := RDUniform.new()
	normal_layer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	normal_layer_uniform.binding = 2
	normal_layer_uniform.add_id(depth_sampler) # reusamos el mismo sampler
	normal_layer_uniform.add_id(normal_roughness_rid)
	

	var bindings: Array[RDUniform] = [color_layer_uniform, depth_layer_uniform, normal_layer_uniform]
	
	var groups := Vector3i((size.x - 1) / 32, (size.y - 1) / 32, 1)
	var uniform_set := rd.uniform_set_create(bindings, shader, 0)
	var compute_list := rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	rd.compute_list_dispatch(compute_list, groups.x, groups.y, groups.z)
	rd.compute_list_end()
	
	rd.free_rid(uniform_set)
