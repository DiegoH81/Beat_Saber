extends Node3D
class_name Generator

signal song_ended()
signal beam_warning(lane: int, phase: int)
signal shield_blocked()

@export_category("Beam")
@export var beam_interval: float = 8.0
@export var warn_yellow_time: float = 1.3
@export var warn_red_time: float = 0.6
@export var beam_speed: float = 40.0
@export var beam_radius: float = 0.105
@export var beam_hold: float = 0.4
@export_flags_3d_physics var shield_mask: int = 8

var _beam_timer: float = 0.0
var _beam_busy: bool = false
var _beam_charge: MeshInstance3D
var _beam_charge_tween: Tween

const SPECIAL_GROUP := "special_enemy"
const BEAM_AUDIO_ATTACK_TIME := 0.9

@onready var _beam_audio: AudioStreamPlayer = $BeamAudio
@onready var _shield_hit_audio: AudioStreamPlayer = $ShieldHitAudio

@export_category("Dependencies")
@export var player_vr: XROrigin3D
@export var n_beats: int = 3
@export var enemy: PackedScene
@export var skin_enemy: PackedScene

@export_category("Attributes")
@export var hit_window: float = 1.5
@export var points: Array[Node3D]

@export_category("Special Enemy")
@export_range(0.0, 1.0) var second_special_chance: float = 0.35
@export var special_color: Color = Color(1.0, 0.8, 0.0)

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

func roll_specials() -> PackedInt32Array:
	var special_indices := PackedInt32Array()
	var next_special_time := randf_range(6.0, 10.0)
	for i in notes.size():
		var first := notes[i]
		if first.exect_time < next_special_time:
			continue
		if first.exect_time >= duration_max:
			break

		special_indices.append(i)
		var last_special_time := first.exect_time
		if randf() < second_special_chance:
			var candidates: Array[int] = []
			var window_start := first.exect_time + 0.8
			var window_end := first.exect_time + 1.5
			for j in range(i + 1, notes.size()):
				var candidate := notes[j]
				if candidate.exect_time > window_end or candidate.exect_time >= duration_max:
					break
				if candidate.exect_time >= window_start and candidate.lane != first.lane:
					candidates.append(j)
			if not candidates.is_empty():
				var second_index: int = candidates.pick_random()
				special_indices.append(second_index)
				last_special_time = notes[second_index].exect_time

		next_special_time = last_special_time + randf_range(6.0, 10.0)
	return special_indices

func start_song(indices: PackedInt32Array) -> void:
	for i in indices:
		if i >= 0 and i < notes.size():
			notes[i].add_to_group(SPECIAL_GROUP)
	set_physics_process(true)

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

func _shield_hit_dist(lane: int) -> float:
	var start := points[lane].global_position
	var dir := -global_transform.basis.z
	var end := start + dir * maxf(dir.dot(player_vr.global_position - start), 0.1)

	var q := PhysicsRayQueryParameters3D.create(start, end)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.collision_mask = shield_mask

	var space := get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	for _i in 32:
		var r := space.intersect_ray(q)
		if r.is_empty():
			return -1.0
		var area := r["collider"] as Node3D
		if area and area.is_visible_in_tree():
			return start.distance_to(r["position"])
		excluded.append(r["rid"])
		q.exclude = excluded
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
	if _beam_charge_tween:
		_beam_charge_tween.kill()
	if phase == 2:
		if is_instance_valid(_beam_charge):
			_beam_charge.queue_free()
			_beam_charge = null
		return
	if lane < 0 or lane >= points.size():
		return

	if phase == 1:
		_beam_audio.play(maxf(0.0, BEAM_AUDIO_ATTACK_TIME - warn_red_time))

	if not is_instance_valid(_beam_charge):
		var orb := SphereMesh.new()
		orb.radius = beam_radius * 2.0
		orb.height = orb.radius * 2.0
		_beam_charge = MeshInstance3D.new()
		_beam_charge.mesh = orb
		_beam_charge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_beam_charge)
		_beam_charge.global_position = points[lane].global_position
		_beam_charge.scale = Vector3.ONE * 0.25

	var charge_color := Color(1.0, 0.55, 0.12) if phase == 0 else Color(1.0, 0.14, 0.05)
	_beam_charge.material_override = _beam_material(charge_color)
	var charge_size := 0.85 if phase == 0 else 1.45
	var charge_time := warn_yellow_time if phase == 0 else warn_red_time
	_beam_charge_tween = _beam_charge.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_beam_charge_tween.tween_property(_beam_charge, "scale", Vector3.ONE * charge_size, charge_time)

func _beam_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _beam_cylinder(pivot: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.01
	cylinder.radial_segments = 16
	cylinder.rings = 0
	cylinder.material = _beam_material(color)

	var mesh := MeshInstance3D.new()
	mesh.mesh = cylinder
	mesh.rotation_degrees.x = -90
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mesh)
	return mesh

@rpc("authority", "call_local", "reliable")
func _fire_beam(lane: int, hit_dist: float) -> void:
	if lane < 0 or lane >= points.size() or not is_instance_valid(player_vr):
		return

	if not _beam_audio.playing:
		_beam_audio.play(BEAM_AUDIO_ATTACK_TIME)

	var start := points[lane].global_position
	var dir := -global_transform.basis.z

	var dist := maxf(dir.dot(player_vr.global_position - start), 0.1)
	if hit_dist > 0.0:
		dist = hit_dist

	var pivot := Node3D.new()
	pivot.name = "BossBeam"
	add_child(pivot, true)
	pivot.global_position = start
	pivot.look_at(start + dir)

	var core := _beam_cylinder(pivot, beam_radius * 0.58, Color(1.0, 0.8, 0.53))
	var shell := _beam_cylinder(pivot, beam_radius * 1.7, Color(1.0, 0.1, 0.04, 0.43))

	var tw := pivot.create_tween()
	tw.tween_method(func(length: float) -> void:
		for mesh in [core, shell]:
			var cylinder := mesh.mesh as CylinderMesh
			cylinder.height = maxf(length, 0.01)
			mesh.position.z = -length * 0.5,
		0.0, dist, dist / beam_speed)
	if hit_dist > 0.0:
		tw.tween_callback(_play_shield_impact)
	tw.tween_interval(beam_hold)
	tw.tween_property(pivot, "scale", Vector3(0.03, 0.03, 1.0), 0.16)
	tw.tween_callback(pivot.queue_free)

func _play_shield_impact() -> void:
	_shield_hit_audio.play()
	shield_blocked.emit()
