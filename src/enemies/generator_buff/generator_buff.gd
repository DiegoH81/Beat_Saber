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


func _ready() -> void:
	set_process(false)

func start_spawning(reference_camera: Camera3D) -> void:
	if scene == null or reference_camera == null or not multiplayer.is_server():
		return
	if multiplayer.get_peers().is_empty():
		return
	var basis := reference_camera.global_transform.basis
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	_spawn_right = forward.cross(Vector3.UP)
	_spawn_center = reference_camera.global_position + forward * spawn_distance
	_spawn_center.y += fall_distance * 0.5
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	if _time < spawn_interval or _objects.size() >= max_objects:
		return
	_time = 0.0

	var spawn_position := to_local(_spawn_center + _spawn_right * randf_range(-spawn_half_width, spawn_half_width))
	_spawn_powerup.rpc(_next_id, POWERUPS.pick_random(), spawn_position)
	_next_id += 1

@rpc("authority", "call_local", "reliable")
func _spawn_powerup(id: int, kind: String, spawn_position: Vector3) -> void:
	var obj: Node3D = scene.instantiate()
	obj.name = "Powerup%d" % id
	obj.add_to_group(kind)
	obj.position = spawn_position
	_style_powerup(obj, kind)
	add_child(obj)
	obj.set_meta("fall_limit", obj.global_position.y - fall_distance)
	_objects.append(obj)
	
	obj.tree_exited.connect(_on_object_removed.bind(obj))

func _style_powerup(obj: Node3D, kind: String) -> void:
	var tint: Color = COLORS[kind]
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.8
	material.roughness = 0.75
	for child in obj.get_children():
		if child is MeshInstance3D:
			child.material_override = material
			match kind:
				RATE:
					var diamond := BoxMesh.new()
					diamond.size = Vector3(0.7, 0.7, 0.6)
					child.mesh = diamond
					child.rotation.z = PI / 4.0
				SCORE:
					var ring := TorusMesh.new()
					ring.inner_radius = 0.29
					ring.outer_radius = 0.52
					child.mesh = ring
					child.rotation.x = PI / 2.0


func _on_object_removed(obj: Node3D) -> void:
	_objects.erase(obj)


func _physics_process(delta: float) -> void:
	for i in range(_objects.size() - 1, -1, -1):
		var obj: Node3D = _objects[i]
		if not is_instance_valid(obj):
			_objects.remove_at(i)
			continue
		obj.global_position.y -= speed * delta
		if obj.global_position.y < float(obj.get_meta("fall_limit")):
			obj.queue_free()
