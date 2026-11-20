extends Node

@export var turret_controller: TurrentController

func _ready() -> void:
	if not OS.has_feature("mobile"):
		pass #server canva.visible = false
	else:
		pass # menu aparezca deferente de la turrent_controller.current_turret o canva.visible = true
