extends Node3D

const SIZE := Vector2(12.0, 6.75)

@onready var _shooting: Node3D = $DisparoYPotenciadores
@onready var _defense: Node3D = $DefensaYTorretas


func _ready() -> void:
	# The pages sit side by side in the editor and share a position during play.
	_defense.position = _shooting.position
	show_page(0)
	_process(0.0)


func show_page(index: int) -> void:
	_shooting.visible = index == 0
	_defense.visible = index == 1


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var corner := get_viewport().get_visible_rect().size
	var center := camera.project_position(corner * 0.5, 1.0)
	var edge := camera.project_position(corner, 1.0) - center
	var half_width := absf(edge.dot(camera.global_basis.x.normalized()))
	var half_height := absf(edge.dot(camera.global_basis.y.normalized()))
	var fit := 1.84 * minf(half_width / SIZE.x, half_height / SIZE.y)
	global_transform = Transform3D(camera.global_basis.orthonormalized().scaled(Vector3.ONE * fit), center)
