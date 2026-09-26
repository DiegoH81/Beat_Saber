extends Level

var xr_interface: XRInterface

var number_: int = 0

func _ready():
	#AudioManager.play_music("test")
	VisualManager.register_world_env($Ambient)
	pass

func _unhandled_input(event: InputEvent) -> void:
	#if event.is_action_pressed("Escape"):
	#	get_tree().quit()
	if event.is_action_pressed("p_button"):
		if number_ == 0:
			VisualManager.change_shader("classic")
			number_=1
		elif number_ == 1:
			VisualManager.change_shader("toon")
			number_=2
		elif number_ == 2:
			VisualManager.change_shader("new_mill")
			number_=3
		elif number_ == 3:
			VisualManager.change_shader("new_dec")
			number_=0
			
