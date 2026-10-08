extends Node3D

@onready var text_1_tutorial: MeshInstance3D = $Text1_TUTORIAL
@onready var text_2_tutorial: MeshInstance3D = $Text2_TUTORIAL
@onready var text_3_tutorial: MeshInstance3D = $Text3_TUTORIAL

@onready var pop_up_3d: Node3D = $"../PopUp3d"

var tutorial_texts: Array[MeshInstance3D] = []


func enable_text_only(active_id : int) -> void:
	for i in range(tutorial_texts.size()):
		tutorial_texts[i].visible = (i == active_id)

func _ready() -> void:
	tutorial_texts = [text_1_tutorial, text_2_tutorial, text_3_tutorial]
	
	enable_text_only(-1)
	
	print("popup: ", pop_up_3d)
	if is_instance_valid(pop_up_3d) and pop_up_3d.has_signal("popup_finished"):
		AudioManager.pause_music()
		await pop_up_3d.popup_finished
		AudioManager.resume_music()
	
	await _run_tutorial()
	
func _run_tutorial() -> void:
	enable_text_only(0)
	await get_tree().create_timer(3.0).timeout

	enable_text_only(1)
	await get_tree().create_timer(3.0).timeout

	enable_text_only(2)
	await get_tree().create_timer(2.0).timeout

	enable_text_only(-1)
