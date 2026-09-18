extends Area3D
class_name Enemy

var exect_time: float
var lane: int
var angle_offset: float
var intensity: float

func init(data: Dictionary) -> void:
	exect_time = data.get("time", 0.0)
	lane = data.get("lane", 0)
	angle_offset = data.get("angle_offset", 0.0)
	intensity = data.get("intensity", 0.0) * 2
	
	scale = Vector3(intensity,intensity,intensity)
	rotate_z(angle_offset)
