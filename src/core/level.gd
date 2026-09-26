extends Node3D
class_name Level

@export var player_vr: XROrigin3D
@export var generator: Generator
@export var ambient: WorldEnvironment

var number: int = 0

func _enter_tree() -> void:
	AudioManager.play_music(name)
	VisualManager.register_world_env(ambient)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p_button"):
		if number == 0:
			VisualManager.change_shader("classic")
			number=1
		elif number == 1:
			VisualManager.change_shader("toon")
			number=2
		elif number == 2:
			VisualManager.change_shader("new_mill")
			number=3
		elif number == 3:
			VisualManager.change_shader("new_dec")
			number=0
	
	if event.is_action_pressed("f_button"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
