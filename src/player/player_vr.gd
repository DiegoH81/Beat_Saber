extends XROrigin3D

@export_category("Dependencies")
@export var camera: XRCamera3D

@export_category("Attributes")
@export var mouse_sensitivity: float = 0.003
@export var move_speed: float = 3.0

var xr_interface: XRInterface
var is_vr_active: bool = false
var rotation_target: Vector3 = Vector3.ZERO

func _ready() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	
	if xr_interface and xr_interface.is_initialized():
		enable_vr_mode()
	else:
		enable_keyboard_mode()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Toggle VR"):
		if is_vr_active:
			enable_keyboard_mode()
		else:
			enable_vr_mode()
		return

	if not is_vr_active and event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_target.y -= event.relative.x * mouse_sensitivity
		rotation_target.x -= event.relative.y * mouse_sensitivity
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-89), deg_to_rad(89))
		
		camera.rotation.x = rotation_target.x
		rotation.y = rotation_target.y

func enable_vr_mode() -> void:
	is_vr_active = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().use_xr = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	
	rotation_target = Vector3.ZERO
	camera.transform.basis = Basis.IDENTITY
	rotation = Vector3.ZERO
	print("VR enabled")

func enable_keyboard_mode() -> void:
	is_vr_active = false
	get_viewport().use_xr = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	camera.transform.basis = Basis.IDENTITY
	camera.position = Vector3.ZERO
	rotation_target = Vector3.ZERO
	rotation = Vector3.ZERO
	print("WIMP on")

func _process(delta: float) -> void:
	if is_vr_active:
		return

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()

	var forward := camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	var move_direction := (forward * input_dir.y + right * input_dir.x)
	global_position += move_direction * move_speed * delta
