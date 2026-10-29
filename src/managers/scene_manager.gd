extends Node

var scene_container: Node = null
var current_scene: Node = null
var player_vr: XROrigin3D = null
var base: Node = null


@onready var first_scene: PackedScene = preload("res://src/ui/main_menu/main_menu_3D.tscn")
const MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/main_menu_3D.tscn")
const LEVELS_PATH: String = "res://levels_data/"

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
	
	if player_vr != null and current_scene == null:
		to_menu()

func register_base(node: Node) -> void:
	base = node

func register_player(player: XROrigin3D) -> void:
	player_vr = player
	
	if scene_container != null and current_scene == null:
		to_menu()

func to_menu() -> void:
	if not scene_container or not is_instance_valid(player_vr):
		push_warning("SceneManager: Esperando a scene_container y player_vr...")
		return
	
	if player_vr.has_method("fade_to"):
		await player_vr.fade_to(0.0, 0.4)
	
	for child in scene_container.get_children():
		if child != player_vr:
			child.queue_free()
	
	var menu = MENU_SCENE.instantiate()
	scene_container.add_child(menu)
	
	var pivot_node: Node3D = null
	if menu.has_node("camera_pivot"):
		pivot_node = menu.get_node("camera_pivot") as Node3D
	elif "camera_pivot" in menu and is_instance_valid(menu.camera_pivot):
		pivot_node = menu.camera_pivot
		
	if pivot_node:
		apply_remote_tracking(pivot_node, player_vr)
	
	if "is_paused" in player_vr:
		player_vr.is_paused = true
	
	if player_vr.has_method("fade_to"):
		await player_vr.fade_to(1.0, 0.4)
			
	current_scene = menu
	
func to_level(level_id: String) -> void:
	if not scene_container or not player_vr:
		push_warning("SceneManager: Intentando ir a nivel sin scene_container o player_vr.")
		return
	
	if player_vr.has_method("fade_to"):
		await player_vr.fade_to(0.0, 0.5)
	
	if "is_paused" in player_vr:
		player_vr.is_paused = false
	
	if "pause" in player_vr and player_vr.pause:
		for connection in player_vr.pause.get_connections():
			player_vr.pause.disconnect(connection.callable)
		
	for child in scene_container.get_children():
		if child != player_vr:
			child.queue_free()
	
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
		player_vr.rotation = level.spawn.rotation
		apply_remote_tracking(level.spawn, player_vr)
	
	var sword_res: Resource = load(LEVELS_PATH + "data/" + level_id + "/models/sword.glb")
	if sword_res != null:
		_setup_swords(sword_res)
		
	if "pause" in player_vr and player_vr.pause and level.pause_menu:
		player_vr.pause.connect(level.pause_menu.pause)
		
	current_scene = level
	
	if player_vr.has_method("fade_to"):
		await player_vr.fade_to(1.0, 0.5)

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
