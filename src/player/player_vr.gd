extends XROrigin3D

signal pause

@export_category("Dependencies")
@export var camera: XRCamera3D
@export var head: Node3D
@export var left_sword: Node3D
@export var right_sword: Node3D
@export var left_hand: Node3D
@export var right_hand: Node3D
@export var ring: MeshInstance3D
@export var fade: MeshInstance3D

@export var sword_scene: PackedScene

@export_category("Attributes")
@export var mouse_sensitivity: float = 0.003
@export var move_speed: float = 3.0

var xr_interface: XRInterface
var is_vr_active: bool = false
var rotation_target: Vector3 = Vector3.ZERO

const HOLD_TIME: float = 1.5
var timer = HOLD_TIME
var is_paused: bool = false
var _fade_alpha: float = 0.0

func _ready() -> void:
	ring.visible = false
	xr_interface = XRServer.find_interface("OpenXR")
	
	if xr_interface and xr_interface.is_initialized():
		enable_vr_mode()
	else:
		enable_keyboard_mode()
	
	if sword_scene == null:
		var sword_res: Resource = load("res://levels_data/test/sword_test.tscn")
		right_sword.add_child(sword_res.instantiate())
		left_sword.add_child(sword_res.instantiate())
	else:
		right_sword.add_child(sword_scene.instantiate())
		left_sword.add_child(sword_scene.instantiate())

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
	
	#rotation_target = Vector3.ZERO
	#rotation = Vector3.ZERO
	print("VR enabled")

func enable_keyboard_mode() -> void:
	is_vr_active = false
	get_viewport().use_xr = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) 
	
	rotation_target = Vector3.ZERO
	rotation = Vector3.ZERO
	print("WIMP on")

func _process(delta: float) -> void:
	if not is_paused and right_hand.global_position.distance_to(left_hand.global_position) < 0.15:
		ring.visible = true
		timer -= delta
		var mat:ShaderMaterial= ring.material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("progress", 1.0 - timer / HOLD_TIME)
		if timer <= 0:
			pause.emit()
			timer = HOLD_TIME
			is_paused = true
	else:
		timer = HOLD_TIME
		ring.visible = false

	if is_vr_active:
		camera.global_transform = Transform3D(camera.global_transform.basis, head.global_position)
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
	
	if Input.is_key_pressed(KEY_SPACE):
		global_position.y += move_speed * delta
	if Input.is_key_pressed(KEY_SHIFT):
		global_position.y -= move_speed * delta

func fade_to(target: float, duration: float = 0.5) -> void:
	var mat := fade.material_override as ShaderMaterial
	if mat == null:
		return

	var target_alpha := 1.0 - target   # target 1.0 = normal, 0.0 = negro
	fade.visible = true

	if duration > 0.0:
		var tw := create_tween()
		tw.tween_method(
			func(v: float) -> void:
				_fade_alpha = v
				mat.set_shader_parameter("alpha", v),
			_fade_alpha, target_alpha, duration)
		await tw.finished
	else:
		_fade_alpha = target_alpha
		mat.set_shader_parameter("alpha", target_alpha)

	if target_alpha <= 0.0:
		fade.visible = false
