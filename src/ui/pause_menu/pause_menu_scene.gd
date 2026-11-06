extends Node3D

@onready var bar_music: Node3D = $Music/BAR_music
@onready var bar_sfx: Node3D = $Effects/BAR_sfx

@onready var resume_button: Area3D = $ResumeButton
@onready var quit_button: Area3D = $QuitButton
@onready var inc_music: Area3D = $Music/IncMUSIC
@onready var dec_music: Area3D = $Music/DecMUSIC
@onready var inc_sfx: Area3D = $Effects/IncSFX
@onready var dec_sfx: Area3D = $Effects/DecSFX

var _menu_open: bool = false
var _quitting: bool = false


func _ready() -> void:
	visible = false

	bar_sfx.set_nivel(AudioManager.get_sfx_level())
	bar_music.set_nivel(AudioManager.get_music_level())

	process_mode = Node.PROCESS_MODE_ALWAYS
	disable_buttons()


# ───────────── API pública (la usan SceneManager, botones y teclado) ─────────────
# Solo piden el cambio de estado: la lógica real está en _apply_state()

func pause() -> void:
	_request_state(true)


func resume() -> void:
	_request_state(false)


func _on_resume_button_pressed() -> void:
	resume()


func _on_quit_button_pressed() -> void:
	_request_quit()


# ───────────── Red ─────────────

func _has_remote_peers() -> bool:
	return multiplayer.multiplayer_peer != null and not multiplayer.get_peers().is_empty()


func _request_state(open: bool) -> void:
	if multiplayer.is_server():
		# Servidor (o sin red): aplica y difunde
		_apply_state(open)
		if _has_remote_peers():
			_set_state_on_clients.rpc(open)
	else:
		# Cliente: pide al servidor
		_set_state_on_server.rpc_id(1, open)


# Cliente -> Servidor
@rpc("any_peer", "call_remote", "reliable")
func _set_state_on_server(open: bool) -> void:
	if not multiplayer.is_server():
		return
	_apply_state(open)
	_set_state_on_clients.rpc(open)


# Servidor -> Clientes
@rpc("authority", "call_remote", "reliable")
func _set_state_on_clients(open: bool) -> void:
	_apply_state(open)


func _request_quit() -> void:
	if multiplayer.is_server():
		if _has_remote_peers():
			_quit_on_clients.rpc()
		_apply_quit()
	else:
		_quit_on_server.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _quit_on_server() -> void:
	if not multiplayer.is_server():
		return
	_quit_on_clients.rpc()
	_apply_quit()


@rpc("authority", "call_remote", "reliable")
func _quit_on_clients() -> void:
	_apply_quit()


# ───────────── Lógica local (se ejecuta en ambos dispositivos) ─────────────

func _apply_state(open: bool) -> void:
	if open == _menu_open:
		return
	_menu_open = open
	if open:
		_open_menu()
	else:
		_close_menu()


func _open_menu() -> void:
	_position_in_front_of_camera()

	await get_tree().create_timer(0.5).timeout

	# Si durante la espera llegó un resume, no abrir el menú
	if not _menu_open or not is_inside_tree():
		return

	visible = true
	AudioManager.pause_music()
	get_parent().generator.set_active(false)
	_set_buttons_enabled(true)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_set_buttons_enabled(false)
	get_parent().generator.set_active(true)
	get_parent().player_vr.is_paused = false
	AudioManager.resume_music()
	visible = false


func _apply_quit() -> void:
	if _quitting:
		return
	_quitting = true
	SceneManager.to_menu()


func _set_buttons_enabled(value: bool) -> void:
	resume_button.is_enabled = value
	quit_button.is_enabled = value
	inc_music.is_enabled = value
	dec_music.is_enabled = value
	inc_sfx.is_enabled = value
	dec_sfx.is_enabled = value


func disable_buttons() -> void:
	_set_buttons_enabled(false)


func _position_in_front_of_camera() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var head_transform: Transform3D = camera.global_transform
	var forward_dir: Vector3 = -head_transform.basis.z

	global_position = head_transform.origin + (forward_dir * 1.2)
	global_rotation = camera.global_rotation


# ───────────── Volumen (local a cada dispositivo) ─────────────

func _on_inc_music_pressed() -> void:
	var new_level = AudioManager.increase_music()
	bar_music.set_nivel(new_level)

func _on_dec_music_pressed() -> void:
	var new_level = AudioManager.decrease_music()
	bar_music.set_nivel(new_level)

func _on_inc_sfx_pressed() -> void:
	var new_level = AudioManager.increase_sfx()
	bar_sfx.set_nivel(new_level)

func _on_dec_sfx_pressed() -> void:
	var new_level = AudioManager.decrease_sfx()
	bar_sfx.set_nivel(new_level)


# ───────────── Input ─────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Escape"):
		if _menu_open:
			resume()
		else:
			pause()

	if _menu_open and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_on_inc_music_pressed()
			KEY_DOWN:
				_on_dec_music_pressed()
			KEY_RIGHT:
				_on_inc_sfx_pressed()
			KEY_LEFT:
				_on_dec_sfx_pressed()
