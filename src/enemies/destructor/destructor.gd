extends Area3D
class_name Destructor

func _on_area_entered(area: Area3D) -> void:
	print(area)
	area.queue_free()
