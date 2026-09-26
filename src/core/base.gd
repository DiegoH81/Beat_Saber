extends Node

@export var scene_container: Node

func _ready() -> void:
	SceneManager.register_scene_container(scene_container)
