extends Node
class_name TurrentController

@export var generator: Generator

@export var turrets: Array[Camera3D]
@export var shields: Array[Node3D]

@export var sensitivity: float = 0.002
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

signal ammo_changed(current: int, max: int)

@export var max_ammo: int = 30
@export var fire_cooldown: float = 0.3
@export var min_fire_cooldown: float = 0.05
@export var ammo_per_powerup: int = 10
@export var fire_rate_bonus: float = 0.05

var ammo: int
var next_shot_time: float = 0.0

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
	ammo = max_ammo
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

	ray_instance.global_position = (origin + end) / 2.0

	ray_instance.look_at(
		ray_instance.global_position + direction,
		Vector3.FORWARD
	)
	ray_instance.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	ray_instance.scale = Vector3(
		ray_thickness,
		distance,
		ray_thickness
	)

	ray_instance.visible = true
	ray_timer.start(ray_duration)
	
@rpc("call_local", "any_peer", "reliable")
func destroy_powerup(path: NodePath) -> void:
	var node := get_node_or_null(path)
	if node:
		node.queue_free()

func raycast_from_camera() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if current_turret == null or ammo <= 0 or now < next_shot_time:
		return
	next_shot_time = now + fire_cooldown
	ammo -= 1
	ammo_changed.emit(ammo, max_ammo)

	var origin := current_turret.global_position
	var direction := -current_turret.global_transform.basis.z
	var end := origin + direction * ray_length

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result := current_turret.get_world_3d().direct_space_state.intersect_ray(query)

	if not result.is_empty():
		end = result["position"]
		var enemy := _find_enemy(result["collider"])
		if enemy and enemy.is_in_group(Generator.SPECIAL_GROUP):
			destroy_special.rpc(enemy.get_meta("note_index", -1))
		else:
			var powerup := _find_powerup(result["collider"])
			if powerup:
				if powerup.is_in_group("powerup_ammo"):
					ammo = mini(ammo + ammo_per_powerup, max_ammo)
					ammo_changed.emit(ammo, max_ammo)
				else:
					fire_cooldown = maxf(fire_cooldown - fire_rate_bonus, min_fire_cooldown)
				destroy_powerup.rpc(powerup.get_path())

	var visual_origin := origin + current_turret.global_transform.basis * Vector3(0, -0.25, 0)
	draw_ray.rpc(visual_origin, end)

func _find_powerup(node: Node) -> Node:
	while node:
		if node.is_in_group("powerup_ammo") or node.is_in_group("powerup_rate"):
			return node
		node = node.get_parent()
	return null

func _find_enemy(node: Node) -> Enemy:
	while node:
		if node is Enemy:
			return node
		node = node.get_parent()
	return null

@rpc("call_local", "any_peer", "reliable")
func destroy_special(note_index: int) -> void:
	if generator:
		generator.destroy_note(note_index)

func changed_to_turret(index: int, value: bool = true) -> void:
	if index < 0 or index >= turrets.size():
		return

	if current_turret:
		current_turret.current = false

	current_index = index
	current_turret = turrets[current_index]
	current_turret.current = value

	pitch = current_turret.rotation.x

@rpc("call_local", "any_peer", "reliable")
func set_shield_visible(index: int, value: bool) -> void:
	if index < 0 or index >= shields.size():
		return
	shields[index].visible = value

var shield_pending: Dictionary = {}

func active_shield(index: int) -> void:
	index = _shield_index(index)
	if index < 0 or index >= shields.size():
		return

	if shields[index].visible or shield_pending.get(index, false):
		return

	shield_pending[index] = true
	set_shield_visible.rpc(index, true)
	await get_tree().create_timer(3.0).timeout
	shield_pending[index] = false
	set_shield_visible.rpc(index, false)



func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ALT and not event.echo:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if event.pressed else Input.MOUSE_MODE_CAPTURED
		return

	if current_turret == null:
		return

	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var mouse_motion := event as InputEventMouseMotion

		current_turret.rotate_y(
			-mouse_motion.relative.x * sensitivity
		)

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
		
func _shield_index(i: int) -> int:
	var cols := 4
	return (i / cols) * cols + (cols - 1 - i % cols)
	
func is_shield_active(n: int) -> bool:
	n = _shield_index(n)
	return n >= 0 and n < shields.size() and shields[n].visible
