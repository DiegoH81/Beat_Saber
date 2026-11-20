@tool
extends Node3D

const STATUS_COLORS := {
	NetworkManager.Status.POOR: Color(1.0, 0.23, 0.28),
	NetworkManager.Status.FAIR: Color(1.0, 0.76, 0.18),
	NetworkManager.Status.GOOD: Color(0.23, 0.95, 0.43),
}

@export var follow_network := true
@export var status: NetworkManager.Status = NetworkManager.Status.GOOD:
	set(value):
		status = value
		if is_node_ready():
			_update_status()

var _active_material := StandardMaterial3D.new()

@onready var _bars: Array[MeshInstance3D] = [$Bars/Short, $Bars/Medium, $Bars/Tall]
@onready var _cross: Node3D = $Cross

func _ready() -> void:
	_active_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if not Engine.is_editor_hint() and follow_network:
		NetworkManager.status_changed.connect(_on_network_status_changed)
		status = NetworkManager.status
	_update_status()

func _on_network_status_changed(value: NetworkManager.Status) -> void:
	status = value

func _update_status() -> void:
	_active_material.albedo_color = STATUS_COLORS.get(status, Color.WHITE)
	for i in _bars.size():
		_bars[i].material_override = _active_material if i < int(status) else null
	_cross.visible = status == NetworkManager.Status.DISCONNECTED
