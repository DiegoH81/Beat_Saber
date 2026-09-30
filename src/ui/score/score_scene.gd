extends Node3D

@onready var combo_value: MeshInstance3D = $ComboValue
@onready var multiplier_value: MeshInstance3D = $ProgressCircle/MultiplierValue
@onready var progress_material : ShaderMaterial = $ProgressCircle/Progress.get_active_material(0)

var current_tween: Tween

func set_progress(value: float):
	progress_material.set_shader_parameter("progress", value)

func _ready() -> void:
	ScoreManager.combo_updated.connect(_on_combo_updated)
	ScoreManager.multiplier_updated.connect(_on_multiplier_updated)
	set_progress(0.0)

func _process(delta: float) -> void:
	pass

func _on_combo_updated(new_combo: int) -> void:	
	combo_value.mesh.text = str(new_combo)

func _on_multiplier_updated(progress: float, level: int, just_leveled_up: bool) -> void:	
	if current_tween and current_tween.is_running():
		current_tween.kill()

	if just_leveled_up:
		set_progress(1.0)
		current_tween = create_tween()
		current_tween.tween_interval(0.35) 
		current_tween.tween_callback(func():
				multiplier_value.mesh.text = str(level) 
		)
		
		current_tween.tween_method(set_progress, 1.0, 0.0, 0.15)
	else:
		multiplier_value.mesh.text = str(level)
		
		current_tween = create_tween()
		current_tween.tween_method(set_progress, progress_material.get_shader_parameter("progress"), progress, 0.05)
