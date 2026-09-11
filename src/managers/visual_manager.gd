extends Node
#WORK IN PROGRESS

var player: Node = null
var generator: Node = null

func register_player(node: Node) -> void:
	if not player:
		return
	player = node

func register_generator(node: Node) -> void:
	if not generator:
		return
	generator = node

func change_theme(id) -> void:
	change_shader(id)
	change_weapon_style(id)
	change_enemy_style(id) 

func change_shader(id: String) -> void:
	pass

func change_weapon_style(id: String) -> void:
	pass

func change_enemy_style(id: String) -> void:
	pass
