extends Node

var scene_container: Node = null
var current_scene: Node = null
var player_vr: XROrigin3D = null
var base: Node = null


const MENU_S2_SCENE: PackedScene = preload("res://src/ui/main_menu/main_menu_s2.tscn")

var menu_s2: Node = null
var last_server_ip: String = ""


@onready var first_scene: PackedScene = preload("res://src/ui/main_menu/main_menu_3D.tscn")
const MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/main_menu_3D.tscn")
const LEVELS_PATH: String = "res://levels_data/"
const REQUEST_COOLDOWN_MS: int = 1500


var current_level_id: String = ""
var _round_id: int = 0
var _level_loaded: bool = false
var _song_started: bool = false
var _ready_peers: Dictionary[int, bool] = {}

var _transition_id: int = 0
var _pending_level: String = ""

var _last_dispatch_key: String = ""
var _last_dispatch_ms: int = 0


func reset() -> void:
	AudioManager.stop_music()
	_transition_id += 1
	scene_container = null
	current_scene = null
	player_vr = null
	base = null
	menu_s2 = null
	_pending_level = ""
	current_level_id = ""
	_level_loaded = false
	_song_started = false
	_ready_peers.clear()
	_last_dispatch_key = ""


func on_connection_lost() -> void:
	AudioManager.stop_music()
	_transition_id += 1
	player_vr = null
	current_scene = null
	_pending_level = ""
	current_level_id = ""
	_level_loaded = false
	_song_started = false
	_ready_peers.clear()


func apply_remote_tracking(source_node: Node3D, target_node: Node3D) -> void:
	for child in source_node.get_children():
		if child is RemoteTransform3D:
			child.queue_free()

	var remote_transform := RemoteTransform3D.new()
	remote_transform.name = "PlayerTracker"

	remote_transform.update_position = true
	remote_transform.update_rotation = true
	remote_transform.update_scale = false

	source_node.add_child(remote_transform)

	remote_transform.remote_path = target_node.get_path()


func register_scene_container(node: Node) -> void:
	if not node:
		return
	scene_container = node
	_try_start()


func register_base(node: Node) -> void:
	base = node


func register_player(player: XROrigin3D) -> void:
	player_vr = player
	_try_start()


func _try_start() -> void:
	if not is_instance_valid(scene_container) or not is_instance_valid(player_vr):
		return

	if _pending_level != "":
		var id := _pending_level
		_pending_level = ""
		to_level(id)
		return

	if not is_instance_valid(current_scene) or current_scene == menu_s2:
		to_menu()


func _clear_scenes() -> void:
	if not is_instance_valid(scene_container):
		return
	for child in scene_container.get_children():
		if child is XROrigin3D:
			continue
		child.queue_free()



func request_level(level_id: String) -> void:
	if multiplayer.is_server():
		_dispatch_level(level_id)
	else:
		_request_level_on_server.rpc_id(1, level_id)


func request_menu() -> void:
	if multiplayer.is_server():
		_dispatch_menu()
	else:
		_request_menu_on_server.rpc_id(1)


func sync_state_to(peer_id: int) -> void:
	if not multiplayer.is_server() or current_level_id.is_empty():
		return
	if _song_started:
		_load_new_round(current_level_id)
	else:
		_start_level.rpc_id(peer_id, current_level_id, _round_id)


# Client -> Sv
@rpc("any_peer", "call_remote", "reliable")
func _request_level_on_server(level_id: String) -> void:
	if multiplayer.is_server():
		_dispatch_level(level_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_menu_on_server() -> void:
	if multiplayer.is_server():
		_dispatch_menu()


# Sever -> All
@rpc("authority", "call_local", "reliable")
func _start_level(level_id: String, round_id: int) -> void:
	current_level_id = level_id
	_round_id = round_id
	_level_loaded = false
	_song_started = false
	_ready_peers.clear()
	to_level(level_id)

@rpc("any_peer", "call_remote", "reliable")
func _report_level_ready(round_id: int) -> void:
	if not multiplayer.is_server() or round_id != _round_id or current_level_id.is_empty():
		return
	_ready_peers[multiplayer.get_remote_sender_id()] = true
	_try_start_song()

func _try_start_song() -> void:
	if not _level_loaded or _song_started:
		return
	for peer_id in multiplayer.get_peers():
		if not _ready_peers.has(peer_id):
			return

	if _has_remote_peers():
		var level := current_scene as Level
		var special_indices := PackedInt32Array()
		if level.generator:
			special_indices = level.generator.roll_specials()
		_start_song.rpc(_round_id, special_indices)
	else:
		_start_song(_round_id, PackedInt32Array())

@rpc("authority", "call_local", "reliable")
func _start_song(round_id: int, special_indices: PackedInt32Array) -> void:
	if round_id != _round_id or not _level_loaded or _song_started:
		return
	var level := current_scene as Level
	_song_started = true
	level.start_song(special_indices)


@rpc("authority", "call_local", "reliable")
func _start_menu() -> void:
	to_menu()


func _dispatch_level(level_id: String) -> void:
	if not _is_valid_level_id(level_id):
		push_warning("SceneManager: nivel inválido: %s" % level_id)
		return
	if _is_duplicate_dispatch("level:" + level_id):
		return
	_load_new_round(level_id)


func _load_new_round(level_id: String) -> void:
	var next_round := _round_id + 1
	if _has_remote_peers():
		_start_level.rpc(level_id, next_round)
	else:
		_start_level(level_id, next_round)


func _dispatch_menu() -> void:
	if _is_duplicate_dispatch("menu"):
		return
	if _has_remote_peers():
		_start_menu.rpc()
	else:
		_start_menu()


func _has_remote_peers() -> bool:
	return multiplayer.multiplayer_peer != null and not multiplayer.get_peers().is_empty()


func _is_duplicate_dispatch(key: String) -> bool:
	var now := Time.get_ticks_msec()
	if key == _last_dispatch_key and now - _last_dispatch_ms < REQUEST_COOLDOWN_MS:
		return true
	_last_dispatch_key = key
	_last_dispatch_ms = now
	return false


func _is_valid_level_id(level_id: String) -> bool:
	return level_id.is_valid_filename() \
		and FileAccess.file_exists(LEVELS_PATH + "data/" + level_id + "/level.json")


# Transitions
func to_menu_s2() -> void:
	if not is_instance_valid(scene_container):
		push_warning("SceneManager: to_menu_s2 sin scene_container.")
		return

	_transition_id += 1
	var my_id := _transition_id

	if is_instance_valid(player_vr) and player_vr.has_method("fade_to"):
		await player_vr.fade_to(0.0, 0.4)
		if my_id != _transition_id:
			return

	if not is_instance_valid(scene_container):
		return
	if not is_instance_valid(player_vr):
		player_vr = null

	_clear_scenes()

	var menu := MENU_S2_SCENE.instantiate()
	scene_container.add_child(menu)

	menu_s2 = menu
	current_scene = menu

	if is_instance_valid(player_vr) and player_vr.has_method("fade_to"):
		player_vr.fade_to(1.0, 0.4)


func to_menu() -> void:
	if not is_instance_valid(scene_container) or not is_instance_valid(player_vr):
		push_warning("SceneManager: Esperando a scene_container y player_vr...")
		return

	current_level_id = ""
	_level_loaded = false
	_song_started = false
	_ready_peers.clear()
	AudioManager.stop_music()
	_transition_id += 1
	var my_id := _transition_id

	if player_vr.has_method("fade_to"):
		await player_vr.fade_to(0.0, 0.4)

	if my_id != _transition_id \
			or not is_instance_valid(player_vr) \
			or not is_instance_valid(scene_container):
		return

	_clear_scenes()
	menu_s2 = null

	var menu = MENU_SCENE.instantiate()
	scene_container.add_child(menu)
	current_scene = menu

	var pivot_node: Node3D = null
	if menu.get_node_or_null("CameraPath/CameraFollow/CameraPivot") != null:
		pivot_node = menu.get_node_or_null("CameraPath/CameraFollow/CameraPivot") as Node3D
	elif "camera_pivot" in menu and is_instance_valid(menu.camera_pivot):
		pivot_node = menu.camera_pivot

	if pivot_node:
		apply_remote_tracking(pivot_node, player_vr)

	if "is_paused" in player_vr:
		player_vr.is_paused = true

	if player_vr.has_method("fade_to"):
		await player_vr.fade_to(1.0, 0.4)

	if my_id != _transition_id or not is_instance_valid(player_vr):
		return

	player_vr.global_position.y -= 1
	player_vr.global_rotation.y = deg_to_rad(180)


func to_level(level_id: String) -> void:
	if not is_instance_valid(scene_container) or not is_instance_valid(player_vr):
		_pending_level = level_id
		return

	_transition_id += 1
	var my_id := _transition_id
	_pending_level = ""

	if player_vr.has_method("fade_to"):
		await player_vr.fade_to(0.0, 0.5)

	if my_id != _transition_id \
			or not is_instance_valid(player_vr) \
			or not is_instance_valid(scene_container):
		return

	if "is_paused" in player_vr:
		player_vr.is_paused = true

	if "pause" in player_vr and player_vr.pause:
		for connection in player_vr.pause.get_connections():
			player_vr.pause.disconnect(connection.callable)

	_clear_scenes()
	menu_s2 = null
	AudioManager.stop_music()

	await get_tree().process_frame
	if my_id != _transition_id \
			or not is_instance_valid(player_vr) \
			or not is_instance_valid(scene_container):
		return

	var level: Level = load_level_scene(level_id)
	level.name = level_id

	var data: Dictionary = load_level_data(level_id)

	level.player_vr = player_vr
	if level.generator:
		level.generator.player_vr = player_vr
		level.generator.setup(data.get("DURATION", 0.0), data.get("BPM", 0.0), data.get("NOTES", []))

	scene_container.add_child(level)

	if level.spawn != null:
		player_vr.global_position = level.spawn.global_position
		player_vr.global_position.y -= 1
		player_vr.rotation = level.spawn.rotation
		apply_remote_tracking(level.spawn, player_vr)

	var sword_res: Resource = load(LEVELS_PATH + "data/" + level_id + "/models/sword.glb")
	if sword_res != null:
		_setup_swords(sword_res)

	current_scene = level

	if player_vr.has_method("fade_to"):
		await player_vr.fade_to(1.0, 0.5)
	if my_id != _transition_id or not is_instance_valid(level):
		return

	_level_loaded = true
	if multiplayer.is_server():
		_try_start_song()
	else:
		_report_level_ready.rpc_id(1, _round_id)


func _setup_swords(sword_res: Resource) -> void:
	if not player_vr:
		return

	if "right_sword" in player_vr and player_vr.right_sword:
		for i in player_vr.right_sword.get_children():
			if i.name == "sword":
				i.queue_free()
				break
		player_vr.right_sword.add_child(sword_res.instantiate())

	if "left_sword" in player_vr and player_vr.left_sword:
		for i in player_vr.left_sword.get_children():
			if i.name == "sword":
				i.queue_free()
				break
		player_vr.left_sword.add_child(sword_res.instantiate())


func load_level_scene(level_id: String) -> Level:
	var level_scene: PackedScene
	var level_scene_path: String = LEVELS_PATH + "data/" + level_id + "/level.tscn"
	if ResourceLoader.exists(level_scene_path):
		level_scene = load(level_scene_path)
	else:
		level_scene = load("res://levels_data/data/Tutorial/level.tscn")
	return level_scene.instantiate()


func load_level_data(level_id: String) -> Dictionary:
	var level_data_path: String = LEVELS_PATH + "data/" + level_id + "/level.json"

	assert(FileAccess.file_exists(level_data_path), "Level data don't exist: %s" % level_data_path)

	var file: FileAccess = FileAccess.open(level_data_path, FileAccess.READ)
	assert(file, "Can't load level data")

	var json: JSON = JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	assert(error == OK, "Can't parse level data: %s" % json.get_error_message())
	return json.data
