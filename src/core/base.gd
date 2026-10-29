extends Node

@export var scene_container: Node
@export var player_scene: PackedScene

@export var server_ip: String = "127.0.0.1"
@export var port: int = 8910

func _ready() -> void:
	if not OS.has_feature("mobile"):
		_init_vr_server()
		_start_server()
	else:
		scene_container.child_entered_tree.connect(_on_client_child_entered_tree)
		_connect_to_server()

func _init_vr_server() -> void:
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _start_server() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port)
	if error != OK:
		print("Error al iniciar el servidor: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	print("Servidor iniciado en el puerto: ", port)

	_spawn_and_register_server_player()

func _connect_to_server() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(server_ip, port)
	if error != OK:
		print("Error al intentar conectar con el servidor: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	print("Cliente conectándose a ", server_ip, ":", port)

func _spawn_and_register_server_player() -> void:
	if player_scene == null:
		push_error("No se asignó la escena del jugador en player_scene")
		return
		
	var player_instance = player_scene.instantiate()
	player_instance.name = "1"

	scene_container.add_child(player_instance, true)

	if player_instance is XROrigin3D:
		SceneManager.register_player(player_instance)
		SceneManager.register_base(self)
		SceneManager.register_scene_container(scene_container)

func _on_client_child_entered_tree(node: Node) -> void:
	if node is XROrigin3D:
		_setup_client_spectator_camera(node)

		SceneManager.register_player(node)
		SceneManager.register_base(self)
		SceneManager.register_scene_container(scene_container)
		
		if scene_container.child_entered_tree.is_connected(_on_client_child_entered_tree):
			scene_container.child_entered_tree.disconnect(_on_client_child_entered_tree)

func _setup_client_spectator_camera(player_node: Node) -> void:
	var xr_camera = player_node.find_child("XRCamera3D", true, false)
	
	if xr_camera:
		var xr_interface = XRServer.find_interface("OpenXR")
		if not xr_interface or not xr_interface.is_initialized():
			get_viewport().use_xr = false
			
			var spec_cam = player_node.find_child("SpectatorCamera", true, false) as Camera3D
			if not spec_cam:
				spec_cam = Camera3D.new()
				spec_cam.name = "SpectatorCamera"
				xr_camera.add_child(spec_cam)
			
			spec_cam.make_current()
		else:
			get_viewport().use_xr = true
			xr_camera.current = true
