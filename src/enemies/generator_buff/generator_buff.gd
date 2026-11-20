extends Node3D

@export var scene: PackedScene
@export var max_objects: int = 20
@export var speed: float = 2.0
@export var spawn_interval: float = 0.5
const POWERUPS: Array[String] = ["powerup_ammo", "powerup_rate"]

@export var _shape: CollisionShape3D

var _half: Vector3
var _objects: Array[Node3D] = []
var _time: float = 0.0


func _ready() -> void:
	var box := _shape.shape as BoxShape3D
	if scene == null or box == null:
		set_process(false)
		set_physics_process(false)
		return
	_half = box.size * 0.5


func _process(delta: float) -> void:
	_time += delta
	if _time < spawn_interval or _objects.size() >= max_objects:
		return
	_time = 0.0

	var obj: Node3D = scene.instantiate()
	obj.add_to_group(POWERUPS.pick_random())
	add_child(obj)
	obj.position = _shape.position + Vector3(randf_range(-_half.x, _half.x), _half.y, randf_range(-_half.z, _half.z))
	_objects.append(obj)
	# Si el buff se libera desde afuera (por ejemplo, al dispararle), lo saca de la lista.
	obj.tree_exited.connect(_on_object_removed.bind(obj))


func _on_object_removed(obj: Node3D) -> void:
	_objects.erase(obj)


func _physics_process(delta: float) -> void:
	var limit := _shape.position.y - _half.y
	for i in range(_objects.size() - 1, -1, -1):
		var obj: Node3D = _objects[i]
		if not is_instance_valid(obj):
			_objects.remove_at(i)
			continue
		obj.position.y -= speed * delta
		if obj.position.y < limit:
			obj.queue_free()
