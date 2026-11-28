extends Node
class_name TurrentController

const RAIL_TURRET_MODEL := preload("res://assets/p2_rail_turret/p2_rail_turret.fbx")
const TURRET_PLATFORM := preload("res://src/core/turret_platform.tscn")
const TURRET_MOUNT_OFFSET := Vector3(0.38, -0.92, -1.56)
const TURRET_CAMERA_OFFSET := Vector3(-0.14, 0.68, 1.62)
const TURRET_CAMERA_MIN_HEIGHT := 0.30
const RAIL_MUZZLE_POINT := Vector3(0.0, 1.9134, 3.1176)
const CADENCE_BOOST_MS := 5000
const SHIELD_DURATION := 3.0
const SHIELD_COLUMNS := 4
const SHIELD_KEY := KEY_SPACE
const STATION_ATTACK_INTERVAL := 18.0
const STATION_WARNING_TIME := 2.2
const STATION_RECOVERY_TIME := 5.0

enum StationState { READY, WARNING, OFFLINE }

@export var generator: Generator

@export var turrets: Array[Camera3D]
@export var shields: Array[Node3D]

@export var sensitivity: float = 0.002
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

signal ammo_changed(current: int, max: int)
signal reload_started(duration: float)
signal buff_collected(kind: String, ammo_gained: int)
signal turret_changed(index: int)
signal shield_changed(active: bool)
signal station_attack_changed(index: int, state: StationState)

@export var max_ammo: int = 32
@export var fire_cooldown: float = 0.12
@export var min_fire_cooldown: float = 0.05
@export var ammo_per_powerup: int = 10
@export var fire_rate_bonus: float = 0.05

var ammo: int
var next_shot_time: float = 0.0
var _cadence_until_ms: int = 0

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
var _turret_visual: Node3D
var _turret_head: Node3D
var _muzzle: Marker3D
var _turret_mounts: Array[Transform3D] = []
var _power_cell: Node3D
var _power_cell_rest: Vector3
var _ammo_hologram: AmmoHologram

var _bullet_mesh: CapsuleMesh
var _bullet_halo_mesh: QuadMesh
var _muzzle_glow: MeshInstance3D
var _muzzle_glow_tween: Tween
var _shield_shake_tween: Tween
var _glow_texture: GradientTexture2D
var _station_song: Generator
var _station_state := StationState.READY
var _station_target := -1
var _station_timer := STATION_ATTACK_INTERVAL

@export var ui_turret: CanvasLayer
## Posición del holograma de munición relativa a la cabeza de la torreta.
@export var ammo_hologram_offset := Vector3(0.42, 0.20, -0.30)

@export var ray_length: float = 100.0
@export var bullet_speed: float = 75.0
@export var recoil_degrees: float = 1.4
@export var recoil_recovery: float = 0.13
@export var zoom_fov_delta: float = 8.0
@export var zoom_time: float = 0.16

@onready var shot_audio: AudioStreamPlayer = $ShotAudio
@onready var reload_audio: AudioStreamPlayer = $ReloadAudio



func _setup_bullet_mesh() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.76, 0.39)
	material.emission_enabled = true
	material.emission = Color(0.55, 0.27, 0.07)
	_bullet_mesh = CapsuleMesh.new()
	_bullet_mesh.radius = 0.04
	_bullet_mesh.height = 0.23
	_bullet_mesh.radial_segments = 8
	_bullet_mesh.rings = 3
	_bullet_mesh.material = material
	_bullet_halo_mesh = _make_halo(Vector2(0.25, 0.25), Color(1.0, 0.5, 0.17, 0.60))

func _make_halo(size: Vector2, tint: Color) -> QuadMesh:
	if _glow_texture == null:
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.28), Color(1, 1, 1, 0)])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = fade
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.albedo_color = tint
	material.albedo_texture = _glow_texture
	var halo := QuadMesh.new()
	halo.size = size
	halo.material = material
	return halo

func _ready() -> void:
	ammo = max_ammo
	_setup_bullet_mesh()

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
		_setup_turret_visual()
		changed_to_turret(0)

func _setup_turret_visual() -> void:
	_turret_visual = TURRET_PLATFORM.instantiate() as Node3D
	add_child(_turret_visual)
	var lift := _turret_visual.get_node("Lift") as Node3D
	for camera in turrets:
		var camera_basis := camera.global_basis.orthonormalized()
		var forward := -camera_basis.z
		forward.y = 0.0
		var mount_basis := Basis.looking_at(forward, Vector3.UP)
		_turret_mounts.append(Transform3D(mount_basis, camera.global_position + mount_basis * TURRET_MOUNT_OFFSET))

	var model := RAIL_TURRET_MODEL.instantiate() as Node3D
	model.rotation.y = PI
	model.scale = Vector3.ONE * 0.32
	lift.add_child(model)
	_power_cell = model.get_node_or_null("StorageGunTurret1") as Node3D

	for part in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_part := part as MeshInstance3D
		mesh_part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(mesh_part.mesh.get_surface_count()):
			var source := mesh_part.get_active_material(surface) as BaseMaterial3D
			if source:
				var material := source.duplicate() as BaseMaterial3D
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				if source.resource_name.begins_with("GreenStorage") or source.resource_name.begins_with("YellowGun"):
					material.albedo_color = Color(0.19, 0.81, 0.88)
					material.emission_enabled = true
					material.emission = Color(0.16, 0.58, 0.66)
					material.emission_energy_multiplier = 1.6
				mesh_part.set_surface_override_material(surface, material)
	_turret_head = Node3D.new()
	_turret_head.name = "RailHead"
	_turret_head.position = model.transform * Vector3(0.0, 1.9, 0.0)
	lift.add_child(_turret_head)
	var barrel := model.get_node("GunRailGunTurret1") as Node3D
	barrel.reparent(_turret_head, true)
	if _power_cell:
		_power_cell.reparent(_turret_head, true)
		_power_cell_rest = _power_cell.position

	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = model.transform * RAIL_MUZZLE_POINT - _turret_head.position
	_turret_head.add_child(_muzzle)
	_muzzle_glow = MeshInstance3D.new()
	_muzzle_glow.mesh = _make_halo(Vector2(0.49, 0.49), Color(0.26, 0.84, 1.0, 0.64))
	_muzzle_glow.scale = Vector3.ONE * 0.38
	_muzzle_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle.add_child(_muzzle_glow)

	_ammo_hologram = AmmoHologram.new()
	_ammo_hologram.name = "AmmoHologram"
	_turret_head.add_child(_ammo_hologram)
	_ammo_hologram.position = ammo_hologram_offset
	
	_ammo_hologram.basis = Basis.looking_at(ammo_hologram_offset - TURRET_CAMERA_OFFSET)
	ammo_changed.connect(_ammo_hologram.set_ammo)
	reload_started.connect(_ammo_hologram.start_reload)
	_ammo_hologram.set_ammo(ammo, max_ammo)

	var lift_motion := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lift_motion.tween_property(lift, "position:y", 0.085, 1.6)
	lift_motion.tween_property(lift, "position:y", 0.0, 1.6)

func _process(delta: float) -> void:
	_update_station_attack(delta)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_mouse_shooting = false
		_set_mouse_zooming(false)
		return
	if _mouse_shooting:
		raycast_from_camera()

func start_station_attacks(song: Generator) -> void:
	if not multiplayer.is_server() and turrets.size() > 1:
		_station_song = song
		song.song_ended.connect(_stop_station_attacks, CONNECT_ONE_SHOT)

func _stop_station_attacks() -> void:
	_station_song = null
	if _station_target >= 0:
		_set_station_state(StationState.READY)
	_station_target = -1

func _update_station_attack(delta: float) -> void:
	if not is_instance_valid(_station_song) or not _station_song.can_process():
		return
	_station_timer -= delta
	if _station_timer > 0.0:
		return

	match _station_state:
		StationState.READY:
			_station_target = current_index
			_station_timer = STATION_WARNING_TIME
			_set_station_state(StationState.WARNING)
		StationState.WARNING:
			_station_timer = STATION_RECOVERY_TIME
			_set_station_state(StationState.OFFLINE)
			_show_station_blast(_turret_mounts[_station_target].origin)
			if current_index == _station_target:
				changed_to_turret(_next_available_station(1))
				_shake_camera(Vector2(0.3, 0.05), 0.32)
		StationState.OFFLINE:
			_set_station_state(StationState.READY)
			_station_target = -1
			_station_timer = STATION_ATTACK_INTERVAL

func _set_station_state(state: StationState) -> void:
	_station_state = state
	station_attack_changed.emit(_station_target, state)

func _station_is_offline(index: int) -> bool:
	return _station_state == StationState.OFFLINE and index == _station_target

func _next_available_station(direction: int) -> int:
	var index := posmod(current_index + direction, turrets.size())
	if _station_is_offline(index):
		index = posmod(index + direction, turrets.size())
	return index

func _show_station_blast(origin: Vector3) -> void:
	var blast := MeshInstance3D.new()
	blast.mesh = _make_halo(Vector2(3.0, 3.0), Color(1.0, 0.36, 0.08, 0.9))
	blast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blast.scale = Vector3.ONE * 0.25
	add_child(blast)
	blast.global_position = origin + Vector3.UP * 0.55
	var motion := blast.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(blast, "scale", Vector3.ONE * 1.35, 0.33)
	motion.parallel().tween_property(blast.mesh.material, "albedo_color:a", 0.0, 0.33)
	motion.tween_callback(blast.queue_free)

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
func show_bullet(origin: Vector3, end: Vector3) -> void:
	var flight := end - origin
	var distance := flight.length()
	if distance <= 0.001:
		return

	var bullet := MeshInstance3D.new()
	bullet.name = "TurretBullet"
	bullet.mesh = _bullet_mesh
	bullet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bullet, true)
	bullet.global_position = origin
	var direction := flight / distance
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	bullet.look_at(end, up)
	bullet.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var halo := MeshInstance3D.new()
	halo.mesh = _bullet_halo_mesh
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bullet.add_child(halo)

	var motion := bullet.create_tween()
	motion.tween_property(bullet, "global_position", end, minf(distance / bullet_speed, 0.65))
	motion.tween_callback(bullet.queue_free)
	
@rpc("call_local", "any_peer", "reliable")
func destroy_powerup(path: NodePath) -> void:
	var node := get_node_or_null(path)
	if node == null or node.is_queued_for_deletion() or not node.get_parent() is PowerupGenerator:
		return
	if multiplayer.is_server():
		if node.is_in_group(PowerupGenerator.SCORE):
			ScoreManager.activate_double_score()
			MatchMetrics.first_action("p2_puntos_dobles_s")
		elif node.is_in_group(PowerupGenerator.RATE):
			MatchMetrics.first_action("p2_cadencia_s")
		elif node.is_in_group(PowerupGenerator.AMMO):
			MatchMetrics.first_action("p2_balas_s")
	node.queue_free()

func raycast_from_camera() -> void:
	var now_ms := Time.get_ticks_msec()
	var now := now_ms / 1000.0
	if current_turret == null or _reloading or ammo <= 0 or now < next_shot_time:
		return
	next_shot_time = now + _shot_interval(now_ms)
	ammo -= 1
	ammo_changed.emit(ammo, max_ammo)
	if current_turret.is_current():
		shot_audio.play()
		_flash_muzzle()

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
					_activate_cadence_boost(now_ms)
					buff_collected.emit("rate", 0)
				else:
					buff_collected.emit("score", 0)
				destroy_powerup.rpc(powerup.get_path())

	var visual_origin := origin + current_turret.global_transform.basis * Vector3(0, -0.25, 0)
	if is_instance_valid(_muzzle):
		visual_origin = _muzzle.global_position
	if direction.dot(end - visual_origin) > 0.0:
		show_bullet.rpc(visual_origin, end)
	if current_turret.is_current():
		_play_recoil()

func _activate_cadence_boost(now_ms: int) -> void:
	_cadence_until_ms = now_ms + CADENCE_BOOST_MS

func _shot_interval(now_ms: int) -> float:
	if now_ms < _cadence_until_ms:
		return maxf(fire_cooldown - fire_rate_bonus, min_fire_cooldown)
	return fire_cooldown

func _flash_muzzle() -> void:
	if not is_instance_valid(_muzzle_glow):
		return
	if _muzzle_glow_tween:
		_muzzle_glow_tween.kill()
	_muzzle_glow.scale = Vector3.ONE
	_muzzle_glow_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_muzzle_glow_tween.tween_property(_muzzle_glow, "scale", Vector3.ONE * 0.38, 0.12)

func play_shield_impact() -> void:
	_shake_camera(Vector2(1.0, 1.0), 0.5)

func _shake_camera(strength: Vector2, duration: float) -> void:
	if not is_instance_valid(current_turret) or not current_turret.is_current():
		return
	if _shield_shake_tween and _shield_shake_tween.is_running():
		return

	var camera := current_turret
	var resting_offset := Vector2(camera.h_offset, camera.v_offset)
	_shield_shake_tween = camera.create_tween()
	_shield_shake_tween.tween_method(func(progress: float) -> void:
		var falloff := pow(1.0 - progress, 2.0)
		camera.h_offset = resting_offset.x + cos(progress * TAU * 3.0) * strength.x * falloff
		camera.v_offset = resting_offset.y + sin(progress * TAU * 2.0) * strength.y * falloff,
		0.0, 1.0, duration)

func _reload() -> void:
	if _reloading or ammo >= max_ammo:
		return

	_reloading = true
	reload_audio.play()
	var duration := reload_audio.stream.get_length()
	_animate_turret_reload(duration)
	reload_started.emit(duration)
	await get_tree().create_timer(duration, false).timeout
	ammo = max_ammo
	_reloading = false
	ammo_changed.emit(ammo, max_ammo)

func _animate_turret_reload(duration: float) -> void:
	if not is_instance_valid(_power_cell):
		return
	var motion := create_tween().set_trans(Tween.TRANS_SINE)
	motion.tween_property(_power_cell, "position", _power_cell_rest + Vector3(0, 0.15, 0.06), duration * 0.35)
	motion.tween_interval(duration * 0.20)
	motion.tween_property(_power_cell, "position", _power_cell_rest, duration * 0.40)

func _play_recoil() -> void:
	if _recoil_tween:
		_recoil_tween.kill()
	_set_recoil_pitch(deg_to_rad(recoil_degrees))
	_recoil_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_method(_set_recoil_pitch, _recoil_pitch, 0.0, recoil_recovery)

func _set_recoil_pitch(value: float) -> void:
	_recoil_pitch = value
	current_turret.rotation.x = pitch + _recoil_pitch
	if is_instance_valid(_turret_head):
		var aim_basis := current_turret.global_basis.orthonormalized()
		_turret_head.global_basis = aim_basis

		var orbit_basis := aim_basis * Basis(Vector3.RIGHT, -_recoil_pitch)
		var pivot := _turret_visual.to_global(_turret_head.position)
		var eye := pivot + orbit_basis * TURRET_CAMERA_OFFSET
		eye.y = maxf(eye.y, _turret_visual.global_position.y + TURRET_CAMERA_MIN_HEIGHT)
		current_turret.global_position = eye

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
	if generator and generator.destroy_note(note_index) and multiplayer.is_server():
		MatchMetrics.first_action("p2_primer_amarillo_s")

func changed_to_turret(index: int, value: bool = true) -> void:
	if index < 0 or index >= turrets.size() or _station_is_offline(index):
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
	if is_instance_valid(_turret_visual):
		_turret_visual.global_transform = _turret_mounts[index]
		_turret_visual.visible = value

	pitch = current_turret.rotation.x
	_set_recoil_pitch(0.0)
	_base_fov = current_turret.fov
	if _mouse_zooming and value:
		_update_zoom()
	turret_changed.emit(current_index)

@rpc("call_local", "any_peer", "reliable")
func set_shields_visible(value: bool) -> void:
	for shield in shields:
		shield.visible = value
	shield_changed.emit(value)

func place_shields_on_lanes(lane_points: Array[Node3D], beam_direction: Vector3) -> void:
	for lane in range(mini(lane_points.size(), shields.size())):
		var shield := shields[_shield_index(lane)]
		var start := lane_points[lane].global_position
		var distance := beam_direction.dot(shield.global_position - start)
		shield.global_position = start + beam_direction * distance

func shield_distance(lane: int, start: Vector3, direction: Vector3) -> float:
	var index := _shield_index(lane)
	if index < 0 or index >= shields.size():
		return 0.0
	return direction.dot(shields[index].global_position - start)

# Un solo escudo: activa los 12 paneles a la vez y bloquea el rayo en
# cualquier carril.
func activate_shield() -> void:
	if multiplayer.is_server() or shields.is_empty() or is_shield_up():
		return
	set_shields_visible.rpc(true)
	await get_tree().create_timer(SHIELD_DURATION).timeout
	set_shields_visible.rpc(false)

func is_shield_up() -> bool:
	return not shields.is_empty() and shields[0].visible


func _input(event: InputEvent) -> void:
	if current_turret == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == SHIELD_KEY:
			activate_shield()
			get_viewport().set_input_as_handled()
			return
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

		_set_recoil_pitch(_recoil_pitch)

	elif event.is_action_pressed("left_arrow"):
		changed_to_turret(_next_available_station(1))

	elif event.is_action_pressed("right_arrow"):
		changed_to_turret(_next_available_station(-1))
		
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_shooting = false
		_set_mouse_zooming(false)
		
static func shield_row_for_lane(lane: int) -> int:
	@warning_ignore("integer_division")
	return lane / SHIELD_COLUMNS

func _shield_index(i: int) -> int:
	return shield_row_for_lane(i) * SHIELD_COLUMNS + (SHIELD_COLUMNS - 1 - i % SHIELD_COLUMNS)
	
func is_shield_active(n: int) -> bool:
	n = _shield_index(n)
	return n >= 0 and n < shields.size() and shields[n].visible
