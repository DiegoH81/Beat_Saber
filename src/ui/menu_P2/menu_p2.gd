extends Node3D

@onready var keyboard := $Camera3D/Keyboard

var _connecting := false
var _opened_ms := 0


func _ready() -> void:
	_opened_ms = Time.get_ticks_msec()
	keyboard.set_value(NetworkManager.last_server_ip)
	NetworkManager.connected.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.reconnect_failed.connect(_on_reconnect_failed)
	if NetworkManager.reconnecting:
		keyboard.set_status("Reconectando…")


func _on_address_submitted(ip: String) -> void:
	if _connecting or NetworkManager.reconnecting:
		return
	if not ip.is_valid_ip_address():
		keyboard.set_status("Escribe una IP válida.")
		return
	_connecting = true
	MatchMetrics.remember_ip_submission((Time.get_ticks_msec() - _opened_ms) / 1000.0)
	keyboard.set_status("Conectando…")
	var error := NetworkManager.connect_to_server(ip)
	if error != OK:
		_show_error("Error de conexión (%d)." % error)


func _on_connected() -> void:
	keyboard.set_status("Conectado")


func _on_connection_failed() -> void:
	if NetworkManager.reconnecting:
		keyboard.set_status("Reconectando…")
		return
	_show_error("No se pudo conectar.")


func _on_reconnect_failed() -> void:
	_show_error("No se pudo reconectar.")


func _show_error(message: String) -> void:
	_connecting = false
	keyboard.set_status(message)
