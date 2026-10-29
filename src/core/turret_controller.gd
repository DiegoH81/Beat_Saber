extends Node
class_name TurrentController

@export var turrets: Array[Camera3D]

func changed_to_turret(index: float, value: bool = true) -> void:
	if index >= 0 and index < turrets.size():
		turrets[index].current = value
