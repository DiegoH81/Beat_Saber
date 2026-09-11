extends Node
class_name Generator

@export var test_enemy: PackedScene

@export var points: Array[Node3D]

var max_intervals: float = 0.3
var intervals: float = 0.3

func _process(delta: float) -> void:
	if intervals < 0:
		intervals = max_intervals
		
		var index: int = randi_range(0, points.size() - 1)
		var intensity: float = randf_range(0.5,3)
		
		var enemy: Node3D = test_enemy.instantiate()
		enemy.scale = Vector3(intensity,intensity,intensity)
		points[index].add_child(enemy)
		
		print(intensity)
		print("Enemigo en la posicion %d con intensidad %.3f" % [index, intensity])
	
	intervals -= delta
