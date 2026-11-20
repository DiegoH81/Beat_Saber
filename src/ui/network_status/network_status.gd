@tool
extends Node3D

enum Status { DISCONNECTED, POOR, FAIR, GOOD }

const STATUS_COLORS := {
	Status.POOR: Color(1.0, 0.23, 0.28),
	Status.FAIR: Color(1.0, 0.76, 0.18),
	Status.GOOD: Color(0.23, 0.95, 0.43),
}

@export var status: Status = Status.GOOD:
	set(value):
		status = value
		if is_node_ready():
			_update_status()

var _active_material := StandardMaterial3D.new()

@onready var _bars: Array[MeshInstance3D] = [$Bars/Short, $Bars/Medium, $Bars/Tall]
@onready var _cross: Node3D = $Cross

func _ready() -> void:
	_active_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_update_status()

func _update_status() -> void:
	_active_material.albedo_color = STATUS_COLORS.get(status, Color.WHITE)
	for i in _bars.size():
		_bars[i].material_override = _active_material if i < int(status) else null
	_cross.visible = status == Status.DISCONNECTED
