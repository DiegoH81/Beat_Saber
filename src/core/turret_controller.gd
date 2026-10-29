extends Node
class_name TurrentController

@export var turrets: Array[Camera3D]

@export var sensitivity: float = 0.002
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

var current_index: int = 0
var current_turret: Camera3D
var pitch: float = 0.0

var ray_mesh_instance: MeshInstance3D
var ray_mesh: ImmediateMesh
var ray_instance: MeshInstance3D
var ray_timer: Timer

@export var ui_turret: CanvasLayer

@export var ray_duration: float = 0.2
@export var ray_thickness: float = 0.015
@export var ray_length: float = 100.0

func setup_ray() -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0

	ray_instance = MeshInstance3D.new()
	ray_instance.mesh = cylinder

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.YELLOW
	material.emission_enabled = true
	material.emission = Color.YELLOW * 3.0
	material.no_depth_test = true

	ray_instance.material_override = material
	ray_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	get_tree().current_scene.add_child(ray_instance)
	ray_instance.visible = false

	ray_timer = Timer.new()
	ray_timer.one_shot = true
	ray_timer.timeout.connect(func():
		ray_instance.visible = false
	)
	add_child(ray_timer)

func _ready() -> void:
	# Inicializar la malla del rayo en todos los pares (servidor y clientes)
	setup_ray()

	if multiplayer.is_server():
		set_process_input(false)
		set_process(false)
		if ui_turret:
			ui_turret.visible = false
		return
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if ui_turret:
		ui_turret.visible = true

	if not turrets.is_empty():
		changed_to_turret(0)

@rpc("call_local", "any_peer", "reliable")
func draw_ray(origin: Vector3, end: Vector3) -> void:
	var direction := end - origin
	var distance := direction.length()

	if distance <= 0.001:
		return

	# Centrar el cilindro entre la cámara y el impacto.
	ray_instance.global_position = (origin + end) / 2.0

	# Orientar el eje Y del cilindro hacia el objetivo.
	ray_instance.look_at(
		ray_instance.global_position + direction,
		Vector3.FORWARD
	)
	ray_instance.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	# Ajustar grosor y longitud.
	ray_instance.scale = Vector3(
		ray_thickness,
		distance,
		ray_thickness
	)

	ray_instance.visible = true
	ray_timer.start(ray_duration)

func raycast_from_camera() -> void:
	if current_turret == null:
		return

	var origin := current_turret.global_position
	var direction := -current_turret.global_transform.basis.z
	var end := origin + direction * ray_length

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result := current_turret.get_world_3d().direct_space_state.intersect_ray(query)

	if not result.is_empty():
		end = result["position"]

	var visual_origin := origin + current_turret.global_transform.basis * Vector3(0, -0.25, 0)
	
	# Transmitir el origen y el destino del rayo a todos los pares
	draw_ray.rpc(visual_origin, end)

func changed_to_turret(index: int, value: bool = true) -> void:
	if index < 0 or index >= turrets.size():
		return

	if current_turret:
		current_turret.current = false

	current_index = index
	current_turret = turrets[current_index]
	current_turret.current = value

	pitch = current_turret.rotation.x

func _input(event: InputEvent) -> void:
	if current_turret == null:
		return

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion

		# Rotación horizontal.
		current_turret.rotate_y(
			-mouse_motion.relative.x * sensitivity
		)

		# Rotación vertical.
		pitch -= mouse_motion.relative.y * sensitivity
		pitch = clamp(
			pitch,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

		current_turret.rotation.x = pitch

	elif event.is_action_pressed("left_arrow"):
		changed_to_turret((current_index + 1) % turrets.size())

	elif event.is_action_pressed("right_arrow"):
		changed_to_turret(
			(current_index - 1 + turrets.size()) % turrets.size()
		)
		
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event.is_action_pressed("click"):
		print("Shot!")
		raycast_from_camera()
