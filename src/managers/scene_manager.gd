extends Node

var scene_container: Node = null
var current_scene: Node = null

@onready var first_scene: PackedScene = preload("res://src/ui/menu.tscn")

const MENU_SCENE: PackedScene = preload("res://src/ui/menu.tscn")
const LEVEL_SELECTOR_SCENE: PackedScene = preload("res://src/ui/level_selector.tscn")

const LEVELS_PATH: String = "res://levels_data/"

func register_scene_container(node: Node) -> void:
	if not node and not scene_container:
		return
	scene_container = node
	
	to_menu()

func to_menu() -> void: 
	if not scene_container:
		return
	
	for child in scene_container.get_children():
		child.queue_free()
	
	var menu = MENU_SCENE.instantiate()
	scene_container.add_child(menu)
	current_scene = menu

func to_level_selector() -> void:
	if not scene_container:
		return
	
	for child in scene_container.get_children():
		child.queue_free()
	
	var level_selector = LEVEL_SELECTOR_SCENE.instantiate()
	scene_container.add_child(level_selector)
	current_scene = level_selector

func to_level(level_id: String) -> void:
	if not scene_container:
		return
		
	for child in scene_container.get_children():
		child.queue_free()
	
	var level: Level = load_level_scene(level_id)
	level.name = level_id

	var data: Dictionary = load_level_data(level_id)
	
	print(data.get("DURATION", ""))
	
	level.generator.setup(data.get("DURATION", 0.0),data.get("BPM", 0.0), data.get("NOTES",[]))
	
	scene_container.add_child(level)
	current_scene = level

func load_level_scene(level_id: String) -> Level:
	var level_scene: PackedScene
	var level_scene_path: String = LEVELS_PATH + "data/"+ level_id + "/level.tscn"
	if ResourceLoader.exists(level_scene_path):
		level_scene = load(level_scene_path)
	else:
		level_scene = load("res://levels_data/test/level_test.tscn")
	return level_scene.instantiate()

func load_level_data(level_id: String) -> Dictionary:
	var level_data_path: String = LEVELS_PATH + "data/"+ level_id + "/level.json"
	
	assert(FileAccess.file_exists(level_data_path), "Level data don't exist")
	
	var file: FileAccess = FileAccess.open(level_data_path, FileAccess.READ)
	assert(file, "Can't load level data")
		 
	var json: JSON = JSON.new()
	var error:= json.parse(file.get_as_text())
	file.close()
	
	assert(error == OK, "Can't parse level data: %s" % json.get_error_message())
	
	var data: Dictionary = json.data
	
	return data
	
