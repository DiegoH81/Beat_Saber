extends Area3D
class_name Destructor

signal hit_registered(amount: int)

func _on_area_entered(area: Area3D) -> void:
	if area is Enemy:
		area.queue_free()
		
		if name == "SwordDestructor":
			ScoreManager.add_hit()
			AudioManager.play_sfx("default",position)
			print("HIT")
		else:
			ScoreManager.register_miss()
