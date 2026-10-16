@tool
extends Area3D

signal pressed

@export var timer: Timer
@export var timer_wait_time: float = 1
@onready var start_color: Color = button_material.albedo_color
@onready var end_color: Color = start_color.lightened(0.8)

var button_progress: float = 0

@export_group("Text")
@export var text: String = "None":
	set(value):
		text = value
		_update_button()


@export_range(16, 512, 8) var font_size: int = 128:
	set(value):
		font_size = value
		_update_button()


@export_group("3D Setup")
@export var button_size: Vector3 = Vector3(2.0, 0.6, 0.2):
	set(value):
		button_size = value
		_update_button()

@export var auto_width: bool = false:
	set(value):
		auto_width = value
		_update_button()

@export var padding: float = 0.5:
	set(value):
		padding = value
		_update_button()

# Visuals of mat and text
@export_group("Visuals")
@export var button_material: Material:
	set(value):
		button_material = value
		_update_button()

@export var text_color: Color = Color.WHITE:
	set(value):
		text_color = value
		_update_button()
		
@export_group("Animation")
@export var hover_scale_factor: float = 1.08


@export var is_enabled: bool = true:
	set(value):
		if is_enabled == value:
			return
		is_enabled = value
		_update_enabled_state()


@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var label_3d: Label3D = $Label3D

@export_group("Lock")
@export var is_locked: bool = false:
	set(value):
		is_locked = value
		_update_lock_visuals()

@export var locked_color: Color = Color(0.25, 0.25, 0.25)

@export var lock_scene: PackedScene:
	set(value):
		lock_scene = value
		_setup_lock()
		
@export var lock_anchor: Vector2 = Vector2(1, 1):
	set(value):
		lock_anchor = value
		_update_button()

@export var lock_offset: Vector3 = Vector3.ZERO: # ajuste fino
	set(value):
		lock_offset = value
		_update_button()

@export var lock_scale: float = 1.0:
	set(value):
		lock_scale = value
		_update_button()


var lock_instance: Node3D
var default_scale: Vector3

func _ready() -> void:
	default_scale = scale
	_setup_lock()

	_update_button()
	
	if not Engine.is_editor_hint():
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		input_event.connect(_on_input_event)
	
	button_material = button_material.duplicate()

func _process(delta: float) -> void:
	if is_locked:
		return
		
	if not timer.is_stopped():
		button_progress = 1.0 - timer.time_left / timer.wait_time
		button_progress = clamp(button_progress,0,1)
		
		button_material.albedo_color = start_color.lerp(
			end_color,
			button_progress
		)
		
func _update_lock_visuals() -> void:
	if not is_node_ready():
		await ready
	if button_material:
		button_material.albedo_color = locked_color if is_locked else start_color
	if label_3d:
		label_3d.modulate = text_color.darkened(0.6) if is_locked else text_color
	
	
	if is_locked and lock_scene and not lock_instance:
		_setup_lock()
	if lock_instance:
		lock_instance.visible = is_locked

	var icon := get_node_or_null("LockIcon")
	if icon:
		icon.visible = is_locked
	if is_locked:
		scale = default_scale

func _update_button() -> void:
	if not is_node_ready():
		await ready

	# Label 3d config
	if label_3d:
		label_3d.text = text
		label_3d.font_size = font_size
		label_3d.modulate = text_color

	# Bttn size
	var final_size: Vector3 = button_size

	if auto_width and label_3d:
		var approx_text_width: float = text.length() * (font_size * 0.001)
		final_size.x = approx_text_width + padding

	# Box re-size
	if mesh_instance:
		var box_mesh: BoxMesh
		if mesh_instance.mesh is BoxMesh:
			box_mesh = mesh_instance.mesh
		else:
			box_mesh = BoxMesh.new()
			mesh_instance.mesh = box_mesh
		
		if box_mesh.is_local_to_scene() == false:
			box_mesh = box_mesh.duplicate()
			mesh_instance.mesh = box_mesh
			
		box_mesh.size = final_size
		
		if button_material:
			mesh_instance.material_override = button_material
	
	
	# Re-size collision
	if collision_shape:
		var box_shape: BoxShape3D
		if collision_shape.shape is BoxShape3D:
			box_shape = collision_shape.shape
		else:
			box_shape = BoxShape3D.new()
			collision_shape.shape = box_shape

		if box_shape.is_local_to_scene() == false:
			box_shape = box_shape.duplicate()
			collision_shape.shape = box_shape

		box_shape.size = final_size

	# Move label 3D
	if label_3d:
		label_3d.position.z = (final_size.z / 2.0) + 0.01
		
	_position_lock(final_size)



# Interaction
func _on_mouse_entered() -> void:
	if Engine.is_editor_hint() or not is_enabled or is_locked:
		return
	var tween = create_tween()
	tween.tween_property(self, "scale", default_scale * hover_scale_factor, 0.12).set_trans(Tween.TRANS_QUAD)

func _on_mouse_exited() -> void:
	if Engine.is_editor_hint() or not is_enabled or is_locked:
		return
	var tween = create_tween()
	tween.tween_property(self, "scale", default_scale, 0.12).set_trans(Tween.TRANS_QUAD)

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if Engine.is_editor_hint() or not is_enabled or is_locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("pressed")

func _on_area_entered(area: Area3D) -> void:
	if Engine.is_editor_hint() or not is_enabled or is_locked:
		return
	if timer.is_stopped():
		timer.start(timer_wait_time)

func _on_area_exited(area: Area3D) -> void:
	if not timer.is_stopped():
		timer.stop()
		timer.wait_time = timer_wait_time
	button_material.albedo_color = start_color
	button_progress = 0.0

func set_enabled(enabled: bool) -> void:
	is_enabled = enabled
	
func _update_enabled_state() -> void:
	visible = is_enabled
	if not is_node_ready():
		await ready
	if collision_shape:
		collision_shape.set_deferred("disabled", not is_enabled)


func _on_timer_timeout() -> void:
	if is_locked:
		timer.stop()
		return
		
	emit_signal("pressed")
	timer.start(timer_wait_time)
	button_material.albedo_color = start_color
	button_progress = 0.0

func _setup_lock() -> void:
	if not is_node_ready():
		return
	if lock_instance:
		lock_instance.queue_free()
		lock_instance = null
	if lock_scene and is_locked:
		lock_instance = lock_scene.instantiate()
		add_child(lock_instance)
		_update_button()

func _position_lock(final_size: Vector3) -> void:
	if not lock_instance:
		return
	lock_instance.position = Vector3(
		lock_anchor.x * final_size.x / 2.0,
		lock_anchor.y * final_size.y / 2.0,
		final_size.z / 2.0
	) + lock_offset
	lock_instance.scale = Vector3.ONE * lock_scale
