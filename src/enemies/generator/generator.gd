extends Node3D
class_name Generator

signal song_ended()
signal beam_warning(lane: int, phase: int)

@export_category("Beam")
@export var beam_interval: float = 8.0
@export var warn_yellow_time: float = 1.3
@export var warn_red_time: float = 0.6
@export var beam_speed: float = 40.0
@export var beam_radius: float = 0.08
@export var beam_hold: float = 0.4
@export_flags_3d_physics var shield_mask: int = 1

var _beam_timer: float = 0.0
var _beam_busy: bool = false

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

	_beam_timer += delta
	if not _beam_busy and _beam_timer >= beam_interval and _is_authority():
		_beam_timer = 0.0
		_run_beam()

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

func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

# Distancia desde el lane hasta el primer escudo visible, o -1.0 si no hay ninguno
func _shield_hit_dist(lane: int) -> float:
	var start := points[lane].global_position
	var dir := -global_transform.basis.z
	var end := start + dir * maxf(dir.dot(player_vr.global_position - start), 0.1)

	var q := PhysicsRayQueryParameters3D.create(start, end)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.collision_mask = shield_mask

	var space := get_world_3d().direct_space_state
	while true:
		var r := space.intersect_ray(q)
		if r.is_empty():
			return -1.0
		var area := r["collider"] as Node3D
		if area and area.is_visible_in_tree():
			return start.distance_to(r["position"])
		q.exclude.append(r["rid"]) # escudo oculto: ignorarlo y seguir
	return -1.0

func _run_beam() -> void:
	if points.is_empty():
		return
	_beam_busy = true
	var lane := randi() % points.size()

	_warn.rpc(lane, 0)
	await get_tree().create_timer(warn_yellow_time).timeout
	_warn.rpc(lane, 1)
	await get_tree().create_timer(warn_red_time).timeout
	_warn.rpc(lane, 2)

	_fire_beam.rpc(lane, _shield_hit_dist(lane))

	await get_tree().create_timer(2.0).timeout
	_beam_busy = false

@rpc("authority", "call_local", "reliable")
func _warn(lane: int, phase: int) -> void:
	beam_warning.emit(lane, phase)

@rpc("authority", "call_local", "reliable")
func _fire_beam(lane: int, hit_dist: float) -> void:
	if lane < 0 or lane >= points.size() or not is_instance_valid(player_vr):
		return

	var start := points[lane].global_position
	var dir := -global_transform.basis.z

	var dist := maxf(dir.dot(player_vr.global_position - start), 0.1)
	if hit_dist > 0.0:
		dist = hit_dist

	var pivot := Node3D.new()
	get_tree().current_scene.add_child(pivot)
	pivot.global_position = start
	pivot.look_at(start + dir)

	var cyl := CylinderMesh.new()
	cyl.top_radius = beam_radius
	cyl.bottom_radius = beam_radius
	cyl.height = 0.01
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyl.material = mat

	var mesh := MeshInstance3D.new()
	mesh.mesh = cyl
	mesh.rotation_degrees.x = -90
	pivot.add_child(mesh)

	var tw := pivot.create_tween()
	tw.tween_method(func(l: float) -> void:
		cyl.height = maxf(l, 0.01)
		mesh.position.z = -l * 0.5, 0.0, dist, dist / beam_speed)
	tw.tween_interval(beam_hold)
	tw.tween_callback(pivot.queue_free)
