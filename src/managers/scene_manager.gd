extends Node

var scene_container: Node = null
var current_scene: Node = null

@onready var first_scene: PackedScene = preload("res://src/ui/menu.tscn")

const MENU_SCENE: PackedScene = preload("res://src/ui/menu.tscn")
const LEVEL_SELECTOR_SCENE: PackedScene = preload("res://src/ui/level_selector.tscn")

const LEVELS_PATH: String = "res://levels_data/scenes/"

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
	
	print(LEVELS_PATH + level_id)
	var level_scene: PackedScene = load(LEVELS_PATH + level_id + ".tscn")
	var level: Node = level_scene.instantiate()
	scene_container.add_child(level)
	current_scene = level
