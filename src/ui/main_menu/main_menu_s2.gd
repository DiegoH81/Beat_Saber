extends Node

@export var button: Button
@export var line_edit: LineEdit
@export var label_3: Label
@export var numerical: GridContainer

const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "DEL"]


func _ready() -> void:
	label_3.text = ""
	line_edit.virtual_keyboard_enabled = false
	line_edit.text = NetworkManager.last_server_ip
	line_edit.caret_column = line_edit.text.length()

	NetworkManager.connected.connect(_on_connected_to_server)
	NetworkManager.connection_failed.connect(_on_connection_failed)

	NetworkManager.reconnect_failed.connect(_on_reconnect_failed)

	var children := numerical.get_children()
	for i in mini(children.size(), KEYS.size()):
		var b := children[i] as Button
		if b:
			b.pressed.connect(_on_key_pressed.bind(KEYS[i]))

	if NetworkManager.reconnecting:
		label_3.text = "Reconectando a %s..." % NetworkManager.last_server_ip


func _on_key_pressed(key: String) -> void:
	if line_edit.has_selection():
		line_edit.delete_text(line_edit.get_selection_from_column(), line_edit.get_selection_to_column())
		if key == "DEL":
			line_edit.grab_focus()
			return
	if key == "DEL":
		var col := line_edit.caret_column
		if col > 0:
			line_edit.delete_text(col - 1, col)
			line_edit.caret_column = col - 1
	else:
		line_edit.insert_text_at_caret(key)
	line_edit.grab_focus()


func _on_button_pressed(_submitted_text: String = "") -> void:
	if button.disabled:
		return
	var ip := line_edit.text.strip_edges()

	if ip.is_empty():
		_show_error("Escribe la IP del servidor.")
		return
	if not ip.is_valid_ip_address():
		_show_error("La IP no es válida.")
		return

	button.disabled = true
	label_3.text = "Conectando..."

	var error := NetworkManager.connect_to_server(ip)
	if error != OK:
		_show_error("No se pudo iniciar la conexión (error %d)." % error)


func _on_connected_to_server() -> void:
	label_3.text = "Conectado"


func _on_connection_failed() -> void:
	if NetworkManager.reconnecting:
		label_3.text = "Reconectando a %s..." % NetworkManager.last_server_ip
		return
	_show_error("No se pudo conectar a esa IP. Revisa que el servidor esté activo.")


func _on_reconnect_failed() -> void:
	_show_error("No se pudo reconectar a %s. Revisa que el servidor esté activo." % NetworkManager.last_server_ip)


func _show_error(message: String) -> void:
	label_3.text = message
	button.disabled = false
