extends Node
class_name Generator

@export var test_enemy: PackedScene

@export var points: Array[Node3D]

var max_intervals: float = 2
var intervals: float = 2

func _process(delta: float) -> void:
	if intervals < 0:
		intervals = max_intervals
		var random_value: int = randi_range(0, points.size() - 1)
		points[random_value].add_child(test_enemy.instantiate())
	
	intervals -= delta
