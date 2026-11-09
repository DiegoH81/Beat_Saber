extends Node

@export var scene_container: Node
@export var player_scene: PackedScene

@export var server_ip: String = "172.20.10.4"
@export var port: int = 8910

const RECONNECT_TIMEOUT_MS: int = 15000
const RECONNECT_RETRY_DELAY: float = 1.0

var _reconnecting: bool = false
var _reconnect_deadline_ms: int = 0


signal reconnect_failed

func _ready() -> void:
	SceneManager.reset()

	if not OS.has_feature("mobile"):
		_init_vr_server()
		_start_server()
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	else:
		scene_container.child_entered_tree.connect(_on_client_child_entered_tree)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		SceneManager.register_base(self)
		SceneManager.register_scene_container(scene_container)
		SceneManager.to_menu_s2()


func _init_vr_server() -> void:
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _on_peer_connected(id: int) -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer:
		var p := peer.get_peer(id)
		if p:
			p.set_timeout(32, 2000, 4000)

	# Late join: si el host ya está en un nivel, el cliente que acaba de
	# conectarse debe ir al mismo nivel.
	SceneManager.sync_state_to(id)


func _on_peer_disconnected(id: int) -> void:
	print("Cliente desconectado: ", id)
	_reset_server.call_deferred()


func _reset_server() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null

	get_tree().reload_current_scene()


func _start_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port)
	if error != OK:
		print("Error al iniciar el servidor: ", error)
		return

	multiplayer.multiplayer_peer = peer
	print("Servidor iniciado en el puerto: ", port)

	_spawn_and_register_server_player()


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
	if _reconnecting:
		return
	print("Conexión perdida, volviendo al menú e intentando reconectar...")
	multiplayer.multiplayer_peer = null

	for c in scene_container.get_children():
		if c is XROrigin3D:
			c.queue_free()
	SceneManager.on_connection_lost()

	if not scene_container.child_entered_tree.is_connected(_on_client_child_entered_tree):
		scene_container.child_entered_tree.connect(_on_client_child_entered_tree)

	var should_reconnect := not SceneManager.last_server_ip.is_empty()
	if should_reconnect:
		_reconnecting = true
		_reconnect_deadline_ms = Time.get_ticks_msec() + RECONNECT_TIMEOUT_MS

	SceneManager.to_menu_s2()

	if should_reconnect:
		_try_reconnect()


func _try_reconnect() -> void:
	if not _reconnecting:
		return

	if Time.get_ticks_msec() >= _reconnect_deadline_ms:
		print("No se pudo reconectar en %d segundos." % (RECONNECT_TIMEOUT_MS / 1000))
		_reconnecting = false
		reconnect_failed.emit()
		return

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(SceneManager.last_server_ip, port)
	if error != OK:
		await get_tree().create_timer(RECONNECT_RETRY_DELAY).timeout
		_try_reconnect()
		return

	multiplayer.multiplayer_peer = peer
	print("Reintentando conectar a ", SceneManager.last_server_ip)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	if not _reconnecting:
		return
	await get_tree().create_timer(RECONNECT_RETRY_DELAY).timeout
	_try_reconnect()


func _on_connected_to_server() -> void:
	print("Conectado al servidor")
	_reconnecting = false

	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer:
		var server_peer := peer.get_peer(1)
		if server_peer:
			server_peer.set_timeout(64, 5000, 10000)


func _connect_to_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(server_ip, port)
	if error != OK:
		print("Error al intentar conectar con el servidor: ", error)
		return

	multiplayer.multiplayer_peer = peer
	print("Cliente conectándose a ", server_ip, ":", port)


# OJO: el único XROrigin3D que existe en el cliente es el jugador "1" replicado
# por el MultiplayerSpawner, y ese es el que usa el cliente. No filtrar por
# multiplayer.get_unique_id().
func _on_client_child_entered_tree(node: Node) -> void:
	if node is XROrigin3D:
		_setup_client_spectator_camera(node)

		# El jugador va el ÚLTIMO para que el arranque ocurra una sola vez.
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
