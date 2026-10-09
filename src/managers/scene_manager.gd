extends Node

var scene_container: Node = null
var current_scene: Node = null
var player_vr: XROrigin3D = null
var base: Node = null


@onready var first_scene: PackedScene = preload("res://src/ui/main_menu/main_menu_3D.tscn")
const MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/main_menu_3D.tscn")

const LEVELS_PATH: String = "res://levels_data/"

func register_scene_container(node: Node) -> void:
	if not node and not scene_container:
		return
	scene_container = node
	
	to_menu()

func register_base(node: Node) -> void: 
	base = node

func register_player(player: XROrigin3D) -> void:
	player_vr = player

func to_menu() -> void: 
	if not scene_container:
		return
	
	await player_vr.fade_to(0.0, 0.4)
	
	for child in scene_container.get_children():
		child.queue_free()
	
	var menu = MENU_SCENE.instantiate()
	scene_container.add_child(menu)
	player_vr.reparent(menu.camera_pivot)
	player_vr.global_position += Vector3(-2, -0.5, -3)
	player_vr.rotate_y(deg_to_rad(-150))
	current_scene = menu
	player_vr.is_paused = true
	
	await player_vr.fade_to(1.0, 0.4)

func to_level(level_id: String) -> void:
	if not scene_container:
		return
	
	await player_vr.fade_to(0.0, 0.5)
	
	player_vr.reparent(base)
	player_vr.is_paused = false
	for connection in player_vr.pause.get_connections():
		player_vr.pause.disconnect(connection.callable)
		
	for child in scene_container.get_children():
		child.queue_free()
	
	var level: Level = load_level_scene(level_id)
	level.name = level_id

	var data: Dictionary = load_level_data(level_id)
	
	level.player_vr = player_vr
	level.generator.player_vr = player_vr
	level.generator.setup(data.get("DURATION", 0.0), data.get("BPM", 0.0), data.get("NOTES", []))
	
	scene_container.add_child(level)
	
	if level.spawn != null:
		player_vr.global_position = level.spawn.global_position
		player_vr.rotation = level.spawn.rotation
	
	player_vr.pause.connect(level.pause_menu.pause)
	current_scene = level
	
	await player_vr.fade_to(1.0, 0.5)

func load_level_scene(level_id: String) -> Level:
	var level_scene: PackedScene
	var level_scene_path: String = LEVELS_PATH + "data/" + level_id + "/level.tscn"
	if ResourceLoader.exists(level_scene_path):
		level_scene = load(level_scene_path)
	else:
		level_scene = load("res://levels_data/test/level_test.tscn")
	return level_scene.instantiate()

func load_level_data(level_id: String) -> Dictionary:
	var level_data_path: String = LEVELS_PATH + "data/" + level_id + "/level.json"
	
	assert(FileAccess.file_exists(level_data_path), "Level data don't exist")
	
	var file: FileAccess = FileAccess.open(level_data_path, FileAccess.READ)
	assert(file, "Can't load level data")
		 
	var json: JSON = JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	
	assert(error == OK, "Can't parse level data: %s" % json.get_error_message())
	
	var data: Dictionary = json.data
	
	return data
