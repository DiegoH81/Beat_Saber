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

var _beam_timer: float = 0.0
var _beam_busy: bool = false
var _beam_charge: MeshInstance3D
var _beam_charge_tween: Tween
var turret_controller: TurrentController
var _beam_pivot: Node3D
var _beam_meshes: Array[MeshInstance3D] = []
var _beam_reach: float
var _beam_checkpoint: float
var _beam_travel: Tween

const SPECIAL_GROUP := "special_enemy"
const BEAM_AUDIO_ATTACK_TIME := 0.9
const SPECIAL_GAP_MIN := 4.0
const SPECIAL_GAP_MAX := 7.0
const BeamEffects := preload("res://src/enemies/generator/beam_effects.gd")
const BEAM_AURA := preload("res://src/enemies/generator/beam_aura.gdshader")

var _beam_effects := BeamEffects.new()
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

func _ready() -> void:
	add_child(_beam_effects)

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
	var next_special_time := randf_range(SPECIAL_GAP_MIN, SPECIAL_GAP_MAX)
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
				if candidate.exect_time >= window_start:
					candidates.append(j)
			if not candidates.is_empty():
				var second_index: int = candidates.pick_random()
				special_indices.append(second_index)
				last_special_time = notes[second_index].exect_time

		next_special_time = last_special_time + randf_range(SPECIAL_GAP_MIN, SPECIAL_GAP_MAX)
	return special_indices

func start_song(indices: PackedInt32Array, first_beam_delay: float = -1.0) -> void:
	for i in indices:
		if i >= 0 and i < notes.size():
			notes[i].add_to_group(SPECIAL_GROUP)
	if first_beam_delay >= 0.0:
		_beam_timer = beam_interval - first_beam_delay
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

func _run_beam() -> void:
	if points.is_empty() or not is_instance_valid(player_vr):
		return
	_beam_busy = true
	var lane := randi() % points.size()

	_warn.rpc(lane, 0)
	await get_tree().create_timer(warn_yellow_time).timeout
	_warn.rpc(lane, 1)
	await get_tree().create_timer(warn_red_time).timeout
	_warn.rpc(lane, 2)

	if not is_instance_valid(player_vr):
		_beam_busy = false
		return
	var start := points[lane].global_position
	var direction := -global_basis.z.normalized()
	var reach := maxf(direction.dot(player_vr.global_position - start), 0.1)
	var shield_at := turret_controller.shield_distance(lane, start, direction) if turret_controller else 0.0
	_fire_beam.rpc(lane, reach, shield_at)

	await get_tree().create_timer(2.0).timeout
	_beam_busy = false

@rpc("authority", "call_local", "reliable")
func _warn(lane: int, phase: int) -> void:
	beam_warning.emit(lane, phase)
	if _beam_charge_tween:
		_beam_charge_tween.kill()
	if phase == 2:
		_beam_effects.restore_light()
		if is_instance_valid(_beam_charge):
			_beam_charge.queue_free()
			_beam_charge = null
		return
	if lane < 0 or lane >= points.size():
		return

	if phase == 1:
		_beam_effects.dim_light(minf(warn_red_time, 0.24))
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
	material.disable_fog = true
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material

func _beam_cylinder(pivot: Node3D, radius: float, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.01
	cylinder.radial_segments = 16
	cylinder.rings = 0
	cylinder.material = material

	var mesh := MeshInstance3D.new()
	mesh.mesh = cylinder
	mesh.rotation_degrees.x = -90
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mesh)
	return mesh

@rpc("authority", "call_local", "reliable")
func _fire_beam(lane: int, reach: float, shield_at: float) -> void:
	if lane < 0 or lane >= points.size() or not is_instance_valid(player_vr):
		return
	if not _beam_audio.playing:
		_beam_audio.play(BEAM_AUDIO_ATTACK_TIME)

	var start := points[lane].global_position
	var direction := -global_basis.z.normalized()
	_beam_pivot = Node3D.new()
	_beam_pivot.name = "BossBeam"
	add_child(_beam_pivot, true)
	_beam_pivot.global_position = start
	_beam_pivot.look_at(start + direction)

	_beam_effects.dim_light(0.12)
	_beam_effects.flash(_beam_pivot, 0.0, false)
	var aura := ShaderMaterial.new()
	aura.shader = BEAM_AURA
	_beam_meshes = [
		_beam_cylinder(_beam_pivot, beam_radius * 0.95, _beam_material(Color(1.0, 0.97, 0.94))),
		_beam_cylinder(_beam_pivot, beam_radius * 2.1, _beam_material(Color(1.0, 0.25, 0.46, 0.34))),
		_beam_cylinder(_beam_pivot, beam_radius * 4.6, aura),
	]
	_beam_reach = reach
	_beam_checkpoint = shield_at if shield_at > 0.0 and shield_at < reach else reach
	_beam_travel = _beam_pivot.create_tween()
	_beam_travel.tween_method(_resize_beam, 0.0, _beam_checkpoint, _beam_checkpoint / beam_speed)

	if _beam_checkpoint == reach:
		_beam_travel.tween_callback(_finish_beam.bind(false))
	elif multiplayer.is_server():
		await _beam_travel.finished
		var blocked := is_instance_valid(turret_controller) and turret_controller.is_shield_active(lane)
		_resolve_beam.rpc(blocked)

@rpc("authority", "call_local", "reliable")
func _resolve_beam(blocked: bool) -> void:
	if not is_instance_valid(_beam_pivot):
		return
	_beam_travel.kill()
	_resize_beam(_beam_checkpoint)
	if blocked:
		_finish_beam(true)
		return
	_beam_travel = _beam_pivot.create_tween()
	_beam_travel.tween_method(_resize_beam, _beam_checkpoint, _beam_reach, (_beam_reach - _beam_checkpoint) / beam_speed)
	_beam_travel.tween_callback(_finish_beam.bind(false))

func _resize_beam(length: float) -> void:
	for mesh in _beam_meshes:
		var cylinder := mesh.mesh as CylinderMesh
		cylinder.height = maxf(length, 0.01)
		mesh.position.z = -length * 0.5

func _finish_beam(blocked: bool) -> void:
	if blocked:
		_beam_effects.flash(_beam_pivot, _beam_checkpoint, true)
		_play_shield_impact()
	elif multiplayer.is_server():
		ScoreManager.register_beam_hit()
	var fade := _beam_pivot.create_tween()
	_beam_effects.restore_light(beam_hold + 0.16)
	fade.tween_interval(beam_hold)
	fade.tween_property(_beam_pivot, "scale", Vector3(0.03, 0.03, 1.0), 0.16)
	fade.tween_callback(_beam_pivot.queue_free)

func _play_shield_impact() -> void:
	_shield_hit_audio.play()
	shield_blocked.emit()
