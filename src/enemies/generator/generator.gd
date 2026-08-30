extends Node
class_name Generator

@export var test_enemy: PackedScene

@export var points: Array[Node3D]

var memory: int = -1

var max_intervals: float = 2
var intervals: float = 2

func _process(delta: float) -> void:
	if intervals < 0:
		intervals = max_intervals
		
		var index: int
		if memory != -1:
		
			if memory == 2:
				index = 3
			elif memory == 3:
				index = 2
				
			elif memory == 6:
				index = 7
			elif memory == 7:
				index = 6

			memory = -1
		else:
			index = randi_range(0, points.size() - 1)
			memory = index
		points[index].add_child(test_enemy.instantiate())
		
		print(index)
	
	intervals -= delta
