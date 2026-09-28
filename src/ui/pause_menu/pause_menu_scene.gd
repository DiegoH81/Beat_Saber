extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func resume() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;
	get_tree().paused = false;
	animation_player.play_backwards("blur")
	visible = false;
	
func pause() -> void:
	_position_in_front_of_camera()
	
	visible = true;
	get_tree().paused = true;
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;
	animation_player.play("blur")
	
func _position_in_front_of_camera() -> void:
	
	var camera: Camera3D = get_viewport().get_camera_3d()
	
	var head_transform: Transform3D = camera.global_transform
	var forward_dir: Vector3 = -head_transform.basis.z

	global_position = head_transform.origin + (forward_dir * 0.8)
	global_rotation = camera.global_rotation
	

func _on_resume_button_pressed() -> void:
	resume();

func _on_quit_button_pressed() -> void:
	get_tree().quit();


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Escape"):
		if get_tree().paused:
			resume()
		else:
			pause()
