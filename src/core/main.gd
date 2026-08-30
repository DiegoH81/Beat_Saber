extends Node3D

var xr_interface: XRInterface

func _ready():
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Escape"):
		get_tree().quit()
