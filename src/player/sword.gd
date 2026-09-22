extends Node3D

@export var sword: Node3D
@export var hand: Node3D
@export var elbow: Node3D


func _process(delta: float) -> void:
	var direction: Vector3 = elbow.global_position - hand.global_position
	if direction.length_squared() > 0.0001:
		sword.look_at(sword.global_position + direction, Vector3.UP)
		sword.rotate_object_local(Vector3.RIGHT, PI / 2)
