extends Node3D

@onready var puntos_valor: MeshInstance3D = $Puntos_VALOR

@onready var button: Area3D = $Button

func _ready() -> void:
	hide_all()

func show_all() -> void:
	visible = true
	button.is_enabled = true
	set_process_input(true)
	set_process_unhandled_input(true)
	
	if puntos_valor and puntos_valor.mesh is TextMesh:
		puntos_valor.mesh.text = str(ScoreManager.current_score)

func hide_all() -> void:
	visible = false
	button.is_enabled = false
	set_process_input(false)
	set_process_unhandled_input(false)
