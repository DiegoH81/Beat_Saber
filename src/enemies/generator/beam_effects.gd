extends Node3D

const HOT := Color(1.0, 0.22, 0.38)
const SHIELD := Color(0.21, 0.79, 1.0)

var _environment: Environment
var _original_light := Vector3.ONE
var _light_tween: Tween
var _halo_texture: GradientTexture2D

func dim_light(duration: float) -> void:
	if not _environment:
		_environment = get_world_3d().environment
		if not _environment:
			return
		_original_light = Vector3(
			_environment.background_energy_multiplier,
			_environment.ambient_light_energy,
			_environment.fog_light_energy
		)
	_tween_light(_original_light * Vector3(0.55, 0.72, 0.65), duration)

func restore_light(delay: float = 0.0) -> void:
	if _environment:
		_tween_light(_original_light, 0.3, delay)
		_light_tween.tween_callback(_forget_environment)

func _tween_light(target: Vector3, duration: float, delay: float = 0.0) -> void:
	if _light_tween:
		_light_tween.kill()
	_light_tween = create_tween()
	if delay > 0.0:
		_light_tween.tween_interval(delay)
	_light_tween.tween_property(_environment, "background_energy_multiplier", target.x, duration)
	_light_tween.parallel().tween_property(_environment, "ambient_light_energy", target.y, duration)
	_light_tween.parallel().tween_property(_environment, "fog_light_energy", target.z, duration)

func _forget_environment() -> void:
	_environment = null

func _exit_tree() -> void:
	if _environment:
		_environment.background_energy_multiplier = _original_light.x
		_environment.ambient_light_energy = _original_light.y
		_environment.fog_light_energy = _original_light.z

func flash(beam: Node3D, distance: float, blocked: bool) -> void:
	var burst := Node3D.new()
	add_child(burst)
	burst.global_transform = Transform3D(beam.global_basis, beam.to_global(Vector3(0, 0, -distance)))

	var sphere := SphereMesh.new()
	sphere.radius = 0.32 if blocked else 0.19
	sphere.height = sphere.radius * 2.0
	var core := _add_mesh(burst, sphere, Color(1.0, 0.96, 1.0, 0.94), 4.5)
	var fade := burst.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(core, "scale", Vector3.ONE * (2.6 if blocked else 2.0), 0.22)
	fade.tween_property(core.material_override, "albedo_color:a", 0.0, 0.25)

	_flare(burst, HOT, Vector2.ONE * (3.2 if blocked else 1.9), 0.42 if blocked else 0.27)
	_ring(burst, HOT, 1.25 if blocked else 0.8, 0.32)
	_sparks(burst, HOT, 20 if blocked else 10, 0.42)
	if blocked:
		_flare(burst, SHIELD, Vector2(5.1, 0.95), 0.40)
		_flare(burst, Color(0.85, 0.91, 1.0), Vector2(0.65, 3.2), 0.30)
		_ring(burst, SHIELD, 1.65, 0.43)
		_sparks(burst, SHIELD, 28, 0.55)
	burst.create_tween().tween_callback(burst.queue_free).set_delay(0.7)

func _flare(parent: Node3D, color: Color, size: Vector2, duration: float) -> void:
	if not _halo_texture:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 1.0])
		gradient.colors = PackedColorArray([
			Color.WHITE, Color(1, 1, 1, 0.80), Color(1, 1, 1, 0.23), Color(1, 1, 1, 0)
		])
		_halo_texture = GradientTexture2D.new()
		_halo_texture.gradient = gradient
		_halo_texture.fill = GradientTexture2D.FILL_RADIAL
		_halo_texture.fill_from = Vector2(0.5, 0.5)
		_halo_texture.fill_to = Vector2(1.0, 0.5)

	var quad := QuadMesh.new()
	quad.size = size
	var flare := _add_mesh(parent, quad, Color(color, 0.84), 2.6)
	var material := flare.material_override as StandardMaterial3D
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.albedo_texture = _halo_texture
	flare.scale = Vector3.ONE * 0.48
	var bloom := flare.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bloom.tween_property(flare, "scale", Vector3.ONE, duration * 0.68)
	bloom.tween_property(material, "albedo_color:a", 0.0, duration).set_delay(duration * 0.12)

func _ring(parent: Node3D, color: Color, radius: float, duration: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.91
	torus.outer_radius = 1.0
	torus.rings = 36
	torus.ring_segments = 8
	var ring := _add_mesh(parent, torus, Color(color, 0.8), 1.8)
	ring.rotation_degrees.x = 90.0
	ring.scale = Vector3.ONE * 0.18
	var expand := ring.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	expand.tween_property(ring, "scale", Vector3.ONE * radius, duration)
	expand.tween_property(ring.material_override, "albedo_color:a", 0.0, duration)

func _sparks(parent: Node3D, color: Color, count: int, duration: float) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = duration
	particles.explosiveness = 1.0
	particles.direction = Vector3.BACK if color == SHIELD else Vector3.FORWARD
	particles.spread = 105.0
	particles.initial_velocity_min = 1.6
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0, -2.1, 0)
	particles.particle_flag_align_y = true
	var spark := BoxMesh.new()
	spark.size = Vector3(0.022, 0.14, 0.022)
	spark.material = _material(color, 2.0)
	particles.mesh = spark
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	particles.scale_amount_curve = shrink
	parent.add_child(particles)
	particles.emitting = true

func _add_mesh(parent: Node3D, mesh: Mesh, color: Color, energy: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, energy)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_fog = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material
