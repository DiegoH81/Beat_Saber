extends Node

@export var scene_container: Node
@export var player_scene: PackedScene

@export var server_ip: String = "172.20.10.4"
@export var port: int = 8910

func _ready() -> void:
	SceneManager.reset()
	NetworkManager.port = port

	var desktop := not OS.has_feature("mobile")
	var client_requested := OS.get_cmdline_user_args().has("--p2")
	if desktop and not client_requested and _start_server():
		_init_vr_server()
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		return

	get_viewport().use_xr = false
	scene_container.child_entered_tree.connect(_on_client_child_entered_tree)
	NetworkManager.connection_lost.connect(_on_server_disconnected)
	SceneManager.register_base(self)
	SceneManager.register_scene_container(scene_container)
	if desktop and NetworkManager.last_server_ip.is_empty():
		NetworkManager.last_server_ip = "127.0.0.1"
	SceneManager.to_menu_s2()
	if desktop and not client_requested:
		server_ip = "127.0.0.1"
		var error := NetworkManager.connect_to_server(server_ip)
		if error != OK:
			print("Error al intentar conectar con el servidor: ", error)


func _init_vr_server() -> void:
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _on_peer_connected(id: int) -> void:
	SceneManager.sync_state_to(id)


func _on_peer_disconnected(id: int) -> void:
	print("Cliente desconectado: ", id)
	_reset_server.call_deferred()


func _reset_server() -> void:
	NetworkManager.close_connection()
	get_tree().reload_current_scene()


func _start_server() -> bool:
	var error := NetworkManager.start_server()
	if error != OK:
		print("Error al iniciar el servidor: ", error)
		return false

	print("Servidor iniciado en el puerto: ", port)

	_spawn_and_register_server_player()
	return true


func _spawn_and_register_server_player() -> void:
	if player_scene == null:
		push_error("No se asignó la escena del jugador en player_scene")
		return

	var player_instance = player_scene.instantiate()
	player_instance.name = "1"

	scene_container.add_child(player_instance, true)

	if player_instance is XROrigin3D:
		# El jugador va el ÚLTIMO: register_player dispara el arranque (to_menu)
		# una sola vez, con todo ya registrado.
		SceneManager.register_base(self)
		SceneManager.register_scene_container(scene_container)
		SceneManager.register_player(player_instance)


func _on_server_disconnected() -> void:
	print("Conexión perdida, volviendo al menú e intentando reconectar...")

	for c in scene_container.get_children():
		if c is XROrigin3D:
			c.queue_free()
	SceneManager.on_connection_lost()

	if not scene_container.child_entered_tree.is_connected(_on_client_child_entered_tree):
		scene_container.child_entered_tree.connect(_on_client_child_entered_tree)

	SceneManager.to_menu_s2()


func _on_client_child_entered_tree(node: Node) -> void:
	if node is XROrigin3D:
		_setup_client_spectator_camera(node)

		SceneManager.register_base(self)
		SceneManager.register_scene_container(scene_container)
		SceneManager.register_player(node)

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
