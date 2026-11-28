extends Area3D
class_name Destructor

@export var hit_particles_scene: PackedScene

signal hit_registered(amount: int)

func _on_area_entered(area: Area3D) -> void:
	if not area is Enemy or area.is_queued_for_deletion():
		return
	var is_sword := name == "SwordDestructor"
	if is_sword and area.is_in_group(Generator.SPECIAL_GROUP):
		return

	if not multiplayer.is_server():
		if not is_sword:
			area.queue_free()
		return

	var impact_position: Vector3 = area.global_position
	var note_index: int = area.get_meta("note_index", -1)
	area.queue_free()

	if is_sword:
		ScoreManager.add_hit()
		_spawn_hit_particles(impact_position)
		_play_hit_sfx()
	else:
		ScoreManager.register_miss(area.is_in_group(Generator.SPECIAL_GROUP))

	_notify_clients(note_index, is_sword)

func _notify_clients(note_index: int, hit: bool) -> void:
	if note_index < 0 or multiplayer.get_peers().is_empty():
		return
	var level := SceneManager.current_scene as Level
	if level and level.generator:
		level.generator.resolve_note_remote.rpc(note_index, hit)

func _play_hit_sfx() -> void:
	var random_index: int = randi_range(1, 24)
	var audio_path: String = "swing_audios_sword/swing_%d" % random_index
	AudioManager.play_sfx(audio_path, global_position)

func _spawn_hit_particles(pos: Vector3) -> void:
	if hit_particles_scene == null:
		return

	var particles := hit_particles_scene.instantiate() as GPUParticles3D
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
