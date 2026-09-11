extends Node
#WORK IN PROGRESS

var player: Node = null
var generator: Node = null
var world_env: WorldEnvironment

var shader_path: String = "res://assets/shaders/"

func register_player(node: Node) -> void:
	if not node:
		return
	player = node

func register_generator(node: Node) -> void:
	if not node:
		return
	generator = node

func register_world_env(node: Node) -> void:
	if not node:
		return
	world_env = node

func change_theme(id) -> void:
	change_shader(id)
	change_weapon_style(id)
	change_enemy_style(id) 

func change_shader(id: String) -> void:
	if not world_env:
		return
	
	var shader: CompositorEffect = load(shader_path + id + ".gd").new()
	if not shader:
		return
	
	print("Cargando: ", shader_path + id + ".gd")
	print("Shader cargado: ", shader)
	
	world_env.compositor.compositor_effects.clear()
	world_env.compositor.compositor_effects.push_back(shader)
	

func change_weapon_style(id: String) -> void:
	pass

func change_enemy_style(id: String) -> void:
	pass
