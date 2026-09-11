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
		points[index].add_child(test_enemy.instantiate())
		
		print(index)
	
	intervals -= delta
