extends Node3D
class_name HealthBar3D

@export var width: float = 2.0
@export var height: float = 0.15
@export var depth: float = 0.04
@export var color_empty: Color = Color.WHITE
@export var color_full: Color = Color(0.25, 0.25, 0.25)
@export var anim_time: float = 0.25

@onready var fill: MeshInstance3D = $Fill

var _mat: StandardMaterial3D
var _tween: Tween
var _current_ratio: float = 0.0

func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, height, depth)
	fill.mesh = mesh
	
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.material_override = _mat
	
	ScoreManager.misses_updated.connect(_on_misses_updated)
	_set_ratio(_ratio_from(ScoreManager.misses))

func _ratio_from(misses: int) -> float:
	return clampf(float(misses) / float(ScoreManager.MAX_MISSES), 0.0, 1.0)

func _on_misses_updated(misses: int) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_ratio, _current_ratio, _ratio_from(misses), anim_time)

func _set_ratio(r: float) -> void:
	_current_ratio = r
	fill.visible = r > 0.001
	fill.scale.x = maxf(r * width, 0.0001)
	fill.position.x = -width * 0.5 + r * width * 0.5
	_mat.albedo_color = color_empty.lerp(color_full, r)
