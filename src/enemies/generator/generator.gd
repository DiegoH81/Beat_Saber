extends Node
class_name Generator

@export var test_enemy: PackedScene

@export var points: Array[Node3D]

var notes: Array[Enemy]

var index: int = 0

var max_intervals: float = 0.3
var intervals: float = 0.3
var duration_max: float = 0
var duration: float = 0

func setup(duration_data: float, interval: float, notes_data: Array) -> void:
	max_intervals = interval
	intervals = interval
	duration_max = duration_data
	
	load_map(notes_data)

func load_map(notes_data: Array) -> void:
	for note_data in notes_data:
		var enemy: Enemy = test_enemy.instantiate()
		enemy.init(note_data)
		notes.push_back(enemy)

func _process(delta: float) -> void:
	print(duration)
	print(notes[index].exect_time)
	
	if duration >= notes[index].exect_time:
		var enemy: Enemy = notes[index]
		points[enemy.lane].add_child(enemy)
		index += 1
	duration += delta
