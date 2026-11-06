extends Node3D
class_name Generator

signal song_ended()

const SPECIAL_GROUP := "special_enemy"

@export_category("Dependencies")
@export var player_vr: XROrigin3D
@export var n_beats: int = 3
@export var enemy: PackedScene
@export var skin_enemy: PackedScene

@export_category("Attributes")
@export var hit_window: float = 1.5
@export var points: Array[Node3D]

@export_category("Special Enemy")
@export_range(0.0, 1.0) var special_chance: float = 0.1
@export var special_color: Color = Color(1.0, 0.8, 0.0)

var notes: Array[Enemy]
var index: int = 0

var bpm: float = 0
var duration_max: float = 0
var duration: float = 0

var is_song_ended: bool = false

var special_indices := PackedInt32Array()
var _pending_special := PackedInt32Array()
var _map_loaded: bool = false
var _special_ready: bool = false

func _ready() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.peer_connected.connect(_on_peer_connected)
	if _map_loaded:
		_setup_special()

func setup(duration_data: float, bpm_data: float, notes_data: Array) -> void:
	duration_max = duration_data
	bpm = bpm_data
	load_map(notes_data)
	_map_loaded = true
	if is_inside_tree():
		_setup_special()

func load_map(notes_data: Array) -> void:
	for note_data in notes_data:
		var enemy: Enemy = enemy.instantiate()
		enemy.init(note_data)
		enemy.set_skin(skin_enemy)
		enemy.set_meta("note_index", notes.size())
		notes.push_back(enemy)

func destroy_note(i: int) -> void:
	if i < 0 or i >= notes.size():
		return
	var e: Enemy = notes[i]
	if not is_instance_valid(e) or not e.is_in_group(SPECIAL_GROUP):
		return
	if e.has_method("die"):
		e.die()
	else:
		e.queue_free()
func _setup_special() -> void:
	if _special_ready:
		return
	_special_ready = true

	if not multiplayer.has_multiplayer_peer():
		_roll_special()
	elif multiplayer.is_server():
		_roll_special()
		_sync_special.rpc(special_indices)
	elif not _pending_special.is_empty():
		_mark_special(_pending_special)
		_pending_special.clear()

func _roll_special() -> void:
	special_indices.clear()
	for i in notes.size():
		if randf() < special_chance:
			special_indices.append(i)
	_mark_special(special_indices)

@rpc("authority", "call_remote", "reliable")
func _sync_special(indices: PackedInt32Array) -> void:
	if notes.is_empty():
		_pending_special = indices
	else:
		_mark_special(indices)

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server() and not special_indices.is_empty():
		_sync_special.rpc_id(id, special_indices)

func _mark_special(indices: PackedInt32Array) -> void:
	for i in indices:
		if i >= 0 and i < notes.size():
			notes[i].add_to_group(SPECIAL_GROUP)

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

		if enemy.is_in_group(SPECIAL_GROUP):
			_apply_special_color(enemy)

		index += 1
	duration += delta

func _apply_special_color(node: Node) -> void:
	if "modulate" in node:
		node.modulate = special_color
	elif node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = special_color
		node.material_override = mat
	for child in node.get_children():
		_apply_special_color(child)
