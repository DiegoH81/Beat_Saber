extends Control

func resume() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;
	get_tree().paused = false;
	$AnimationPlayer.play_backwards("blur")
	visible = false;
	
func pause() -> void:
	visible = true;
	get_tree().paused = true;
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;
	$AnimationPlayer.play("blur")

func testEsc() -> void:
	if Input.is_action_just_pressed("Escape") and get_tree().paused == false:
		print("Esc presionado")
		pause()
	elif Input.is_action_just_pressed("Escape") and get_tree().paused == true:
		resume()

func _on_resume_pressed() -> void:
	resume();

func _on_quit_pressed() -> void:
	get_tree().quit();

#func _on_restart_pressed() -> void:
#	get_tree().reload_current_scene();

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta) -> void:
	testEsc();
