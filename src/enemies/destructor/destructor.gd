extends Area3D
class_name Destructor

func _on_area_entered(area: Area3D) -> void:
	if area is Enemy:
		area.queue_free()
