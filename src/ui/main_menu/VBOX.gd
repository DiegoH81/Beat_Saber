extends VBoxContainer

#const MAIN_MENU_3D = preload("uid://cyvuy0k531q1g")

func _on_play_button_pressed() -> void:
	SceneManager.to_level_selector()
