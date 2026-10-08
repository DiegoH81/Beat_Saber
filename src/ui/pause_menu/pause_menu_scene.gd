extends Node3D

@onready var bar_music: Node3D = $BAR_music
@onready var bar_sfx: Node3D = $BAR_sfx

@onready var resume_button: Area3D = $ResumeButton
@onready var quit_button: Area3D = $QuitButton
@onready var inc_music: Area3D = $IncMUSIC
@onready var dec_music: Area3D = $DecMUSIC
@onready var inc_sfx: Area3D = $IncSFX
@onready var dec_sfx: Area3D = $DecSFX


func resume() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;
	get_tree().paused = false;
	
	resume_button.is_enabled = false
	quit_button.is_enabled = false
	inc_music.is_enabled = false
	dec_music.is_enabled = false
	inc_sfx.is_enabled = false
	dec_sfx.is_enabled = false
	visible = false;
	
func pause() -> void:
	_position_in_front_of_camera()
	
	resume_button.is_enabled = true
	quit_button.is_enabled = true
	inc_music.is_enabled = true
	dec_music.is_enabled = true
	inc_sfx.is_enabled = true
	dec_sfx.is_enabled = true
	
	visible = true;
	get_tree().paused = true;
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;
	
func disable_buttons() -> void:
	resume_button.is_enabled = false
	quit_button.is_enabled = false
	inc_music.is_enabled = false
	dec_music.is_enabled = false
	inc_sfx.is_enabled = false
	dec_sfx.is_enabled = false
	
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

# Bar INC
func _on_inc_music_pressed() -> void:
	var new_level = AudioManager.increase_music()
	bar_music.set_nivel(new_level)

func _on_dec_music_pressed() -> void:
	var new_level = AudioManager.decrease_music()
	bar_music.set_nivel(new_level)

func _on_inc_sfx_pressed() -> void:
	var new_level = AudioManager.increase_sfx()
	bar_sfx.set_nivel(new_level)
	
func _on_dec_sfx_pressed() -> void:
	var new_level = AudioManager.decrease_sfx()
	bar_sfx.set_nivel(new_level)


func _ready() -> void:
	visible = false
	
	bar_sfx.set_nivel(AudioManager.get_sfx_level())
	bar_music.set_nivel(AudioManager.get_music_level())

	process_mode = Node.PROCESS_MODE_ALWAYS
	disable_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Escape"):
		if get_tree().paused:
			resume()
		else:
			pause()
			
	
	if get_tree().paused and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_on_inc_music_pressed()
			KEY_DOWN:
				_on_dec_music_pressed()
			KEY_RIGHT:
				_on_inc_sfx_pressed()
			KEY_LEFT:
				_on_dec_sfx_pressed()
