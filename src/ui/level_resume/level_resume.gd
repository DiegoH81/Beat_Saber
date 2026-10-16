extends Node3D

@onready var puntos_valor: MeshInstance3D = $Puntos_VALOR

@onready var button: Area3D = $Button

var is_paused: bool = false

func _ready() -> void:
	hide_all()
	button.area_entered.connect(get_parent()._to_next_level.unbind(1))

func _position_in_front_of_camera() -> void:
	
	var camera: Camera3D = get_viewport().get_camera_3d()
	
	var head_transform: Transform3D = camera.global_transform
	var forward_dir: Vector3 = -head_transform.basis.z

	global_position = head_transform.origin + (forward_dir * 1.5)
	global_rotation = camera.global_rotation

func show_all() -> void:
	get_parent().player_vr.is_paused = true
	_position_in_front_of_camera()
	is_paused = true
	visible = true
	button.is_enabled = true
	set_process_input(true)
	set_process_unhandled_input(true)
	
	if puntos_valor and puntos_valor.mesh is TextMesh:
		puntos_valor.mesh.text = str(ScoreManager.current_score)

func hide_all() -> void:
	is_paused = false
	visible = false
	button.is_enabled = false
	set_process_input(false)
	set_process_unhandled_input(false)
