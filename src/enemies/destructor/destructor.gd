extends Area3D
class_name Destructor

signal hit_registered(amount: int)

func _on_area_entered(area: Area3D) -> void:
	if area is Enemy:
		area.queue_free()
		ScoreManager.add_hit(1)
		
		hit_registered.emit(1)
		if name == "SwordDestructor":
			AudioManager.play_sfx("default",position)
			print("HIT")
