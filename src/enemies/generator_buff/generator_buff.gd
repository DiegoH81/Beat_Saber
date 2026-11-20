extends Node3D
class_name PowerupGenerator

@export var scene: PackedScene
@export var max_objects: int = 20
@export var speed: float = 2.0
@export var spawn_interval: float = 0.5
@export var spawn_distance: float = 9.0
@export var spawn_half_width: float = 2.5
@export var fall_distance: float = 4.8

const AMMO := "powerup_ammo"
const RATE := "powerup_rate"
const SCORE := "powerup_score"
const POWERUPS: Array[String] = [AMMO, RATE, SCORE]
const COLORS := {
	AMMO: Color(0.40, 0.85, 0.58),
	RATE: Color(1.0, 0.64, 0.26),
	SCORE: Color(0.53, 0.71, 1.0),
}

var _objects: Array[Node3D] = []
var _time: float = 0.0
var _next_id: int = 0
var _spawn_center: Vector3
var _spawn_right: Vector3
var _halo_texture: GradientTexture2D


func _ready() -> void:
	set_process(false)

func start_spawning(reference_camera: Camera3D, practice_duration: float = 0.0, practice_delay: float = 0.0) -> void:
	if scene == null or reference_camera == null or not multiplayer.is_server():
		return
	if multiplayer.get_peers().is_empty():
		return
	var basis := reference_camera.global_transform.basis
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	_spawn_right = forward.cross(Vector3.UP)
	_spawn_center = reference_camera.global_position + forward * spawn_distance
	_spawn_center.y += fall_distance * 0.5
	if practice_duration > 0.0:
		await get_tree().create_timer(practice_delay, false).timeout
		_spawn_tutorial_powerups(practice_duration)
	set_process(true)

func preview_model(kind: String) -> Node3D:
	var model := Node3D.new()
	_style_powerup(model, kind)
	return model

func _spawn_tutorial_powerups(practice_duration: float) -> void:
	for i in POWERUPS.size():
		var offset := (i - 1) * 1.65
		var spawn_position := to_local(_spawn_center + _spawn_right * offset)
		_spawn_powerup.rpc(_next_id, POWERUPS[i], spawn_position, practice_duration)
		_next_id += 1

func _process(delta: float) -> void:
	_time += delta
	if _time < spawn_interval or _objects.size() >= max_objects:
		return
	_time = 0.0

	var spawn_position := to_local(_spawn_center + _spawn_right * randf_range(-spawn_half_width, spawn_half_width))
	_spawn_powerup.rpc(_next_id, POWERUPS.pick_random(), spawn_position)
	_next_id += 1

@rpc("authority", "call_local", "reliable")
func _spawn_powerup(id: int, kind: String, spawn_position: Vector3, practice_duration: float = 0.0) -> void:
	var obj: Node3D = scene.instantiate()
	obj.name = "Powerup%d" % id
	obj.add_to_group(kind)
	obj.position = spawn_position
	_style_powerup(obj, kind)
	add_child(obj)
	obj.set_meta("fall_limit", obj.global_position.y - fall_distance)
	if practice_duration > 0.0:
		obj.set_meta("fall_speed", fall_distance / practice_duration)
	_objects.append(obj)
	
	obj.tree_exited.connect(_on_object_removed.bind(obj))

func _style_powerup(obj: Node3D, kind: String) -> void:
	var tint: Color = COLORS[kind]
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.65
	material.roughness = 0.5
	for child in obj.get_children():
		if child is MeshInstance3D:
			child.free()

	match kind:
		AMMO:
			var cell := CylinderMesh.new()
			cell.top_radius = 0.19
			cell.bottom_radius = 0.19
			cell.height = 0.68
			cell.radial_segments = 8
			_add_piece(obj, cell, material, Vector3.ZERO)
			var cap := CylinderMesh.new()
			cap.top_radius = 0.27
			cap.bottom_radius = 0.27
			cap.height = 0.11
			cap.radial_segments = 8
			var casing := StandardMaterial3D.new()
			casing.albedo_color = Color(0.19, 0.30, 0.24)
			casing.emission_enabled = true
			casing.emission = tint * 0.16
			for y in [-0.38, 0.38]:
				_add_piece(obj, cap, casing, Vector3(0, y, 0))
		RATE:
			var rail := BoxMesh.new()
			rail.size = Vector3(0.43, 0.13, 0.23)
			for y in [-0.25, 0.15]:
				_add_piece(obj, rail, material, Vector3(-0.16, y, 0), Vector3(0, 0, 0.62))
				_add_piece(obj, rail, material, Vector3(0.16, y, 0), Vector3(0, 0, -0.62))
		SCORE:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.17
			ring.outer_radius = 0.30
			ring.rings = 24
			ring.ring_segments = 8
			_add_piece(obj, ring, material, Vector3(-0.18, -0.10, 0), Vector3(PI / 2.0, -0.2, 0))
			_add_piece(obj, ring, material, Vector3(0.18, 0.10, 0.03), Vector3(PI / 2.0, 0.2, 0))

	_add_powerup_halo(obj, tint)

func _add_piece(parent: Node3D, mesh: Mesh, material: Material, offset: Vector3, angles: Vector3 = Vector3.ZERO) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.position = offset
	piece.rotation = angles
	parent.add_child(piece)

func _add_powerup_halo(obj: Node3D, tint: Color) -> void:
	if _halo_texture == null:
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		fade.colors = PackedColorArray([Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0)])
		_halo_texture = GradientTexture2D.new()
		_halo_texture.gradient = fade
		_halo_texture.fill = GradientTexture2D.FILL_RADIAL
		_halo_texture.fill_from = Vector2(0.5, 0.5)
		_halo_texture.fill_to = Vector2(1.0, 0.5)

	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_material.albedo_texture = _halo_texture
	halo_material.albedo_color = Color(tint, 0.42)
	var halo := QuadMesh.new()
	halo.size = Vector2(1.55, 1.55)
	_add_piece(obj, halo, halo_material, Vector3.ZERO)


func _on_object_removed(obj: Node3D) -> void:
	_objects.erase(obj)


func _physics_process(delta: float) -> void:
	for i in range(_objects.size() - 1, -1, -1):
		var obj: Node3D = _objects[i]
		if not is_instance_valid(obj):
			_objects.remove_at(i)
			continue
		obj.global_position.y -= float(obj.get_meta("fall_speed", speed)) * delta
		if obj.global_position.y < float(obj.get_meta("fall_limit")):
			obj.queue_free()
