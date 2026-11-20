extends Node
class_name TurrentController

@export var generator: Generator

@export var turrets: Array[Camera3D]
@export var shields: Array[Node3D]

@export var sensitivity: float = 0.002
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

signal ammo_changed(current: int, max: int)
signal buff_collected(kind: String, ammo_gained: int)
signal turret_changed(index: int)
signal shield_changed(button_index: int, active: bool)

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
var _recoil_pitch: float = 0.0
var _recoil_tween: Tween

var _mouse_shooting: bool = false
var _mouse_zooming: bool = false
var _base_fov: float = 75.0
var _zoom_tween: Tween
var _reloading: bool = false

var ray_mesh_instance: MeshInstance3D
var ray_mesh: ImmediateMesh
var ray_instance: MeshInstance3D
var ray_timer: Timer

@export var ui_turret: CanvasLayer

@export var ray_duration: float = 0.2
@export var ray_thickness: float = 0.015
@export var ray_length: float = 100.0
@export var recoil_degrees: float = 1.4
@export var recoil_recovery: float = 0.13
@export var zoom_fov_delta: float = 8.0
@export var zoom_time: float = 0.16

@onready var shot_audio: AudioStreamPlayer = $ShotAudio
@onready var reload_audio: AudioStreamPlayer = $ReloadAudio



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

	add_child(ray_instance)
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

func _process(_delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_mouse_shooting = false
		_set_mouse_zooming(false)
		return
	if _mouse_shooting:
		raycast_from_camera()

func _set_mouse_zooming(zooming: bool) -> void:
	if _mouse_zooming == zooming:
		return
	_mouse_zooming = zooming
	_update_zoom()

func _update_zoom() -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	if not is_instance_valid(current_turret):
		return
	var target_fov := maxf(1.0, _base_fov - zoom_fov_delta) if _mouse_zooming else _base_fov
	_zoom_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(current_turret, "fov", target_fov, zoom_time)

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
	if node == null or node.is_queued_for_deletion() or not node.get_parent() is PowerupGenerator:
		return
	if multiplayer.is_server() and node.is_in_group(PowerupGenerator.SCORE):
		ScoreManager.activate_double_score()
	node.queue_free()

func raycast_from_camera() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if current_turret == null or _reloading or ammo <= 0 or now < next_shot_time:
		return
	next_shot_time = now + fire_cooldown
	ammo -= 1
	ammo_changed.emit(ammo, max_ammo)
	if current_turret.is_current():
		shot_audio.play()

	var screen_center := current_turret.get_viewport().get_visible_rect().get_center()
	var origin := current_turret.project_ray_origin(screen_center)
	var direction := current_turret.project_ray_normal(screen_center)
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
				if powerup.is_in_group(PowerupGenerator.AMMO):
					var previous_ammo := ammo
					ammo = mini(ammo + ammo_per_powerup, max_ammo)
					ammo_changed.emit(ammo, max_ammo)
					buff_collected.emit("ammo", ammo - previous_ammo)
				elif powerup.is_in_group(PowerupGenerator.RATE):
					fire_cooldown = maxf(fire_cooldown - fire_rate_bonus, min_fire_cooldown)
					buff_collected.emit("rate", 0)
				else:
					buff_collected.emit("score", 0)
				destroy_powerup.rpc(powerup.get_path())

	var visual_origin := origin + current_turret.global_transform.basis * Vector3(0, -0.25, 0)
	draw_ray.rpc(visual_origin, end)
	if current_turret.is_current():
		_play_recoil()

func _reload() -> void:
	if _reloading or ammo >= max_ammo:
		return

	_reloading = true
	reload_audio.play()
	await get_tree().create_timer(reload_audio.stream.get_length(), false).timeout
	ammo = max_ammo
	_reloading = false
	ammo_changed.emit(ammo, max_ammo)

func _play_recoil() -> void:
	if _recoil_tween:
		_recoil_tween.kill()
	_set_recoil_pitch(deg_to_rad(recoil_degrees))
	_recoil_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_method(_set_recoil_pitch, _recoil_pitch, 0.0, recoil_recovery)

func _set_recoil_pitch(value: float) -> void:
	_recoil_pitch = value
	current_turret.rotation.x = pitch + _recoil_pitch

func _find_powerup(node: Node) -> Node:
	while node:
		if node.get_parent() is PowerupGenerator and not node.is_queued_for_deletion() and (
			node.is_in_group(PowerupGenerator.AMMO) or node.is_in_group(PowerupGenerator.RATE)
			or node.is_in_group(PowerupGenerator.SCORE)
		):
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
		if _recoil_tween:
			_recoil_tween.kill()
		_set_recoil_pitch(0.0)
		if _zoom_tween:
			_zoom_tween.kill()
		current_turret.fov = _base_fov
		current_turret.current = false

	current_index = index
	current_turret = turrets[current_index]
	current_turret.current = value

	pitch = current_turret.rotation.x
	_base_fov = current_turret.fov
	if _mouse_zooming and value:
		_update_zoom()
	turret_changed.emit(current_index)

@rpc("call_local", "any_peer", "reliable")
func set_shield_visible(index: int, value: bool) -> void:
	if index < 0 or index >= shields.size():
		return
	shields[index].visible = value
	shield_changed.emit(_shield_index(index), value)

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
		if event.pressed:
			_mouse_shooting = false
			_set_mouse_zooming(false)
		return

	if current_turret == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reload()
			return
		if event.keycode >= KEY_1 and event.keycode <= KEY_3:
			changed_to_turret(event.keycode - KEY_1)
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var pause_menu := get_parent().get_node_or_null("PauseMenu") as Node3D
			if event.pressed and not event.alt_pressed and (pause_menu == null or not pause_menu.visible):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_set_mouse_zooming(event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_shooting = event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			if _mouse_shooting:
				raycast_from_camera()
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

		current_turret.rotation.x = pitch + _recoil_pitch

	elif event.is_action_pressed("left_arrow"):
		changed_to_turret((current_index + 1) % turrets.size())

	elif event.is_action_pressed("right_arrow"):
		changed_to_turret(
			(current_index - 1 + turrets.size()) % turrets.size()
		)
		
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_shooting = false
		_set_mouse_zooming(false)
		
func _shield_index(i: int) -> int:
	var cols := 4
	return (i / cols) * cols + (cols - 1 - i % cols)
	
func is_shield_active(n: int) -> bool:
	n = _shield_index(n)
	return n >= 0 and n < shields.size() and shields[n].visible
