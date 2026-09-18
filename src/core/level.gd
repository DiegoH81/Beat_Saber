extends Node3D
class_name Level

@export var player_vr: XROrigin3D
@export var generator: Generator

func _enter_tree() -> void:
	AudioManager.play_music(name)
