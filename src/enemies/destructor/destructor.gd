extends Area3D
class_name Destructor

@export var hit_particles_scene: PackedScene

signal hit_registered(amount: int)
	
func _on_area_entered(area: Area3D) -> void:
	if area is Enemy:
		var impact_position: Vector3 = area.global_position
		area.queue_free()
		
		if name == "SwordDestructor":
			ScoreManager.add_hit()
			_spawn_hit_particles(impact_position)
			
			var random_index: int = randi_range(1, 24)
			var audio_path: String = "swing_audios_sword/swing_%d" % random_index
			
			AudioManager.play_sfx(audio_path, global_position, 0.1)
		else:
			ScoreManager.register_miss()

func _spawn_hit_particles(pos: Vector3, color: Color = Color(0.5294, 0.8078, 0.9216)) -> void:
	if hit_particles_scene == null:
		return
		
	var particles := hit_particles_scene.instantiate() as GPUParticles3D
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos

	var mat := particles.process_material.duplicate() as ParticleProcessMaterial
	mat.color = color
	particles.process_material = mat
