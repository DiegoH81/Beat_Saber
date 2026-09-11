extends Node3D

var xr_interface: XRInterface

var number: int = 0

func _ready():
	#AudioManager.play_music("test")
	VisualManager.register_world_env($Ambient)
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Escape"):
		get_tree().quit()
	if event.is_action_pressed("p_button"):
		if number == 0:
			VisualManager.change_shader("classic")
			number=1
		elif number == 1:
			VisualManager.change_shader("toon")
			number=0
			
