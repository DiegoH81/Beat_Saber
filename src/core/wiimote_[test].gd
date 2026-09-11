extends Node3D

var cube_a: MeshInstance3D
var cube_b: MeshInstance3D

var speed := 7.0

func _ready() -> void:
	cube_a = MeshInstance3D.new()
	var mesh_a := BoxMesh.new()
	mesh_a.size = Vector3(0.15, 1.2, 0.05)
	cube_a.mesh = mesh_a
	cube_a.position = Vector3(-1, 0, 0)
	add_child(cube_a)

	cube_b = MeshInstance3D.new()
	var mesh_b := BoxMesh.new()
	mesh_b.size = Vector3(0.15, 1.2, 0.05)
	cube_b.mesh = mesh_b
	cube_b.position = Vector3(1, 0, 0)
	add_child(cube_b)

func _process(d: float) -> void:
	var x0: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var y0: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	
	if abs(x0) < 0.1:
		x0 = 0.0
	if abs(y0) < 0.1:
		y0 = 0.0
		
	cube_a.position.x += x0 * d * speed
	cube_a.position.y -= y0 * d * speed
	cube_a.position.x = clamp(cube_a.position.x, -1.5, 0.0)
	cube_a.position.y = clamp(cube_a.position.y, -1.5, 1.5)


	var x1: float = Input.get_joy_axis(1, JOY_AXIS_LEFT_X)
	var y1: float = Input.get_joy_axis(1, JOY_AXIS_LEFT_Y)
	
	if abs(x1) < 0.1:
		x1 = 0.0
	if abs(y1) < 0.1:
		y1 = 0.0
		
	cube_b.position.x += x1 * d * speed
	cube_b.position.y -= y1 * d * speed
	cube_b.position.x = clamp(cube_b.position.x, 0.0, 1.5)
	cube_b.position.y = clamp(cube_b.position.y, -1.5, 1.5)
