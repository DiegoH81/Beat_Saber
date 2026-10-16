extends Node3D
class_name Generator

signal song_ended()

@export_category("Dependencies")
@export var player_vr: XROrigin3D
@export var n_beats: int = 3
@export var enemy: PackedScene
@export var skin_enemy: PackedScene

@export_category("Attributes")
@export var hit_window: float = 1.5
@export var points: Array[Node3D]

var notes: Array[Enemy]
var index: int = 0

var bpm: float = 0
var duration_max: float = 0
var duration: float = 0

var is_song_ended: bool = false

func setup(duration_data: float, bpm_data: float, notes_data: Array) -> void:
	duration_max = duration_data
	bpm = bpm_data
	load_map(notes_data)

func load_map(notes_data: Array) -> void:
	for note_data in notes_data:
		var enemy: Enemy = enemy.instantiate()
		enemy.init(note_data)
		enemy.set_skin(skin_enemy)
		notes.push_back(enemy)

func set_active(active: bool) -> void:
	var mode := Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	process_mode = mode
	for p in points:
		if is_instance_valid(p):
			p.process_mode = mode

func _physics_process(delta: float) -> void:
	if is_song_ended:
		return
		
	if notes.size() <= index or duration >= duration_max:
		song_ended.emit()
		is_song_ended = true
		return
	
	if duration >= notes[index].exect_time:
		var enemy: Enemy = notes[index]
		enemy.movement.direction = -global_transform.basis.z
		enemy.movement.velocity = (global_position.distance_to(player_vr.global_position) - hit_window) * bpm / (60 * n_beats)
		points[enemy.lane].add_child(enemy)
		index += 1
	duration += delta
