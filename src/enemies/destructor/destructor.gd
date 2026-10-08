extends Area3D
class_name Destructor

signal hit_registered(amount: int)

func _on_area_entered(area: Area3D) -> void:
	if area is Enemy:
		area.queue_free()
		
		if name == "SwordDestructor":
			ScoreManager.add_hit()
			
			var random_index: int = randi_range(1, 24)
			var audio_path: String = "swing_audios_sword/swing_%d" % random_index
			
			AudioManager.play_sfx(audio_path, global_position, 0.01)
		else:
			ScoreManager.register_miss()
