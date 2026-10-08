extends Node3D

@onready var camera_pivot: Node3D = $CameraPath/CameraFollow/CameraPivot
@onready var camera_follow: PathFollow3D = $CameraPath/CameraFollow
@onready var level_selector_pos: Marker3D = $CameraTargets/LevelSelectorPos

# Transitions
func go_to_level_selector() -> void:
	var tween = create_tween().set_parallel(true)

	tween.tween_property(camera_follow,
						 "progress_ratio",
						 1.0,
						 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(camera_pivot,
						 "global_transform:basis",
						 level_selector_pos.global_transform.basis,
						 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	await tween.finished



# Main menu
func _on_play_button_pressed() -> void:
	go_to_level_selector()

# Level selector
func _on_vivaldi_button_pressed() -> void:
	SceneManager.to_level("Vivaldi_four_seasons")

func _on_sing_sing_button_pressed() -> void:
	SceneManager.to_level("Sing_Sing_Sing")

func _on_seven_nation_button_pressed() -> void:
	SceneManager.to_level("Seven_nation_army")

func _on_roommates_button_pressed() -> void:
	SceneManager.to_level("Roommates")
	
func _on_tutorial_button_pressed() -> void:
	SceneManager.to_level("Tutorial")

func _process(delta: float) -> void:	
	if Input.is_action_just_pressed("TEMPORAL_TEST"):
		SceneManager.to_level("Tutorial")
	pass
