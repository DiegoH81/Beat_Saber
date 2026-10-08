extends Node

@export var scene_container: Node
@export var player_vr: XROrigin3D

func _ready() -> void:
	SceneManager.register_player(player_vr)
	SceneManager.register_base(self)
	SceneManager.register_scene_container(scene_container)
