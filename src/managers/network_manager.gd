extends Node

signal status_changed(status: Status)
signal connected
signal connection_failed
signal connection_lost
signal reconnect_failed

enum Status { DISCONNECTED, POOR, FAIR, GOOD }

const GOOD_PING_MS := 100
const FAIR_PING_MS := 200
const SAMPLE_INTERVAL_MS := 500
const RECONNECT_TIMEOUT_MS := 15000
const RECONNECT_RETRY_MS := 1000

var port := 8910
var last_server_ip := ""
var status: Status = Status.DISCONNECTED
var latency_ms := -1
var reconnecting := false

var _next_sample_ms := 0
var _reconnect_deadline_ms := 0
var _retry_at_ms := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)

func start_server() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		_sample_status()
	return error

func connect_to_server(ip: String) -> Error:
	close_connection()
	last_server_ip = ip
	return _open_client()

func close_connection() -> void:
	cancel_reconnect()
	_close_peer()

func _close_peer() -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	_set_status(Status.DISCONNECTED, -1)

func cancel_reconnect() -> void:
	reconnecting = false
	_retry_at_ms = -1

func _open_client() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(last_server_ip, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now >= _next_sample_ms:
		_next_sample_ms = now + SAMPLE_INTERVAL_MS
		_sample_status()
	if not reconnecting:
		return
	if now >= _reconnect_deadline_ms:
		close_connection()
		reconnect_failed.emit()
	elif _retry_at_ms >= 0 and now >= _retry_at_ms:
		_retry_at_ms = -1
		if _open_client() != OK:
			_retry_at_ms = now + RECONNECT_RETRY_MS

func _sample_status() -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not peer or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_set_status(Status.DISCONNECTED, -1)
		return

	var worst_ping := -1
	for id in multiplayer.get_peers():
		var remote := peer.get_peer(id)
		if remote and remote.get_state() == ENetPacketPeer.STATE_CONNECTED:
			worst_ping = maxi(worst_ping, int(remote.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)))

	if worst_ping < 0:
		_set_status(Status.DISCONNECTED, -1)
	elif worst_ping <= GOOD_PING_MS:
		_set_status(Status.GOOD, worst_ping)
	elif worst_ping <= FAIR_PING_MS:
		_set_status(Status.FAIR, worst_ping)
	else:
		_set_status(Status.POOR, worst_ping)

func _set_status(value: Status, ping: int) -> void:
	latency_ms = ping
	if status != value:
		status = value
		status_changed.emit(status)

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if peer:
			var remote := peer.get_peer(id)
			if remote:
				remote.set_timeout(32, 2000, 4000)
	_sample_status()

func _on_peer_disconnected(_id: int) -> void:
	_sample_status()

func _on_connected_to_server() -> void:
	cancel_reconnect()
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer:
		var remote := peer.get_peer(1)
		if remote:
			remote.set_timeout(64, 5000, 10000)
	_sample_status()
	MatchMetrics.send_ip_timing()
	connected.emit()

func _on_server_disconnected() -> void:
	_close_peer()
	if not last_server_ip.is_empty():
		var now := Time.get_ticks_msec()
		reconnecting = true
		_reconnect_deadline_ms = now + RECONNECT_TIMEOUT_MS
		_retry_at_ms = now
	connection_lost.emit()

func _on_connection_failed() -> void:
	_close_peer()
	if reconnecting:
		_retry_at_ms = Time.get_ticks_msec() + RECONNECT_RETRY_MS
	connection_failed.emit()
