extends Control

@export var button: Button
@export var line_edit: LineEdit
@export var label_3: Label
@export var numerical: GridContainer

const PORT := 8910

# Orden de los 12 botones en el GridContainer
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "DEL"]

func _ready() -> void:
	label_3.text = ""
	# Desactivamos el teclado del sistema, porque ya usas el tuyo
	line_edit.virtual_keyboard_enabled = false
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	# Conectar los 12 botones automáticamente
	var children := numerical.get_children()
	for i in mini(children.size(), KEYS.size()):
		var b := children[i] as Button
		if b:
			b.pressed.connect(_on_key_pressed.bind(KEYS[i]))

func _on_key_pressed(key: String) -> void:
	if key == "DEL":
		var col := line_edit.caret_column
		if col > 0:
			line_edit.delete_text(col - 1, col)
			line_edit.caret_column = col - 1
	else:
		line_edit.insert_text_at_caret(key)
	line_edit.grab_focus()

func _on_button_pressed() -> void:
	var ip := line_edit.text.strip_edges()

	if ip.is_empty():
		_show_error("Escribe la IP del servidor.")
		return
	if not ip.is_valid_ip_address():
		_show_error("La IP no es válida.")
		return

	button.disabled = true
	label_3.text = "Conectando..."

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, PORT)
	if error != OK:
		_show_error("No se pudo iniciar la conexión (error %d)." % error)
		return

	multiplayer.multiplayer_peer = peer

func _on_connected_to_server() -> void:
	label_3.text = "Conectado"
	SceneManager.to_menu()

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	_show_error("No se pudo conectar a esa IP. Revisa que el servidor esté activo.")

func _show_error(message: String) -> void:
	label_3.text = message
	button.disabled = false
