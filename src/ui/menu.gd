extends Control

@export var play_button: Button

func _on_play_button_pressed() -> void:
	SceneManager.to_level_selector()
