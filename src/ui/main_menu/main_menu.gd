extends Node3D

@onready var camera_pivot: Node3D = $CameraPath/CameraFollow/CameraPivot
@onready var camera_follow: PathFollow3D = $CameraPath/CameraFollow
@onready var level_selector_pos: Marker3D = $CameraTargets/LevelSelectorPos

@onready var vivaldi_button: Area3D = $VivaldiButton
@onready var sing_sing_sing_button: Area3D = $SingSingSingButton
@onready var seven_nation_army_button: Area3D = $SevenNationArmyButton
@onready var tutorial_button: Area3D = $TutorialButton

@onready var pop_up_3d: Node3D = $PopUp3d
@onready var play_button: Area3D = $PlayButton

@export var ip: MeshInstance3D

@onready var level_buttons: Dictionary = {
	"Tutorial": $TutorialButton,
	"Vivaldi_four_seasons": $VivaldiButton,
	"Sing_Sing_Sing": $SingSingSingButton,
	"Seven_nation_army": $SevenNationArmyButton,
}

# Teclas -> nivel (para el toggle de debug)
const KEY_LEVELS := {
	KEY_1: "Vivaldi_four_seasons",
	KEY_2: "Sing_Sing_Sing",
	KEY_3: "Seven_nation_army",
	KEY_4: "Tutorial",
}


# ───────────── Transiciones ─────────────

func go_to_level_selector() -> void:
	var tween = create_tween().set_parallel(true)

	tween.tween_property(camera_follow,
						 "progress_ratio",
						 1.0,
						 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(camera_pivot,
						 "global_transform:basis",
						 level_selector_pos.global_transform.basis,
						 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	await tween.finished


func _refresh_level_buttons() -> void:
	for level_id in level_buttons:
		level_buttons[level_id].is_locked = not ProgressManager.is_unlocked(level_id)


# ───────────── Menú principal ─────────────

func _on_play_button_pressed() -> void:
	go_to_level_selector()


# ───────────── Selector de niveles ─────────────

func _on_vivaldi_button_pressed() -> void:
	SceneManager.to_level("Vivaldi_four_seasons")

func _on_sing_sing_sing_pressed() -> void:
	SceneManager.to_level("Sing_Sing_Sing")

func _on_seven_nation_army_button_pressed() -> void:
	SceneManager.to_level("Seven_nation_army")

func _on_tutorial_button_pressed() -> void:
	SceneManager.to_level("Tutorial")


# ───────────── Ready / Process ─────────────

func _ready() -> void:
	if OS.has_feature("mobile"):
		$CameraPath/CameraFollow/CameraPivot/Camera3D.current = true
	elif multiplayer.is_server():
		var _finding_ip: String = ""
		for addr in IP.get_local_addresses():
			# Solo IPv4 de red local (192.168.x.x, 172.16-31.x.x, 10.x.x.x)
			if addr.begins_with("192.168.") or addr.begins_with("10."):
				_finding_ip = addr
			if addr.begins_with("172."):
				var second := int(addr.split(".")[1])
				if second >= 16 and second <= 31:
					_finding_ip = addr

		(ip.mesh as TextMesh).text = "Pasa esta IP a tu amigo para jugar juntos: " + _finding_ip

	play_button.is_enabled = false
	pop_up_3d.visible = true
	if pop_up_3d.has_signal("popup_finished"):
		pop_up_3d.popup_finished.connect(_on_popup_finished)

	ProgressManager.progress_changed.connect(_refresh_level_buttons)
	_refresh_level_buttons()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("TEMPORAL_TEST"):
		SceneManager.to_level("Tutorial")


func _on_popup_finished() -> void:
	play_button.is_enabled = true


func _on_exit_button_area_entered(_area: Area3D) -> void:
	get_tree().quit()


# ───────────── Teclas 1-4 sincronizadas por red ─────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if KEY_LEVELS.has(event.keycode):
			_request_toggle_level(KEY_LEVELS[event.keycode])


func _has_remote_peers() -> bool:
	return multiplayer.multiplayer_peer != null and not multiplayer.get_peers().is_empty()


# Quien presiona la tecla llama aquí
func _request_toggle_level(level_id: String) -> void:
	if multiplayer.is_server():
		# Servidor (o sin red): aplica y difunde a los clientes
		_apply_toggle_level(level_id)
		if _has_remote_peers():
			_toggle_level_on_clients.rpc(level_id)
	else:
		# Cliente: pide al servidor que lo aplique y lo difunda
		_toggle_level_on_server.rpc_id(1, level_id)


# Cliente -> Servidor
@rpc("any_peer", "call_remote", "reliable")
func _toggle_level_on_server(level_id: String) -> void:
	if not multiplayer.is_server():
		return
	_apply_toggle_level(level_id)
	_toggle_level_on_clients.rpc(level_id)


# Servidor -> Clientes
@rpc("authority", "call_remote", "reliable")
func _toggle_level_on_clients(level_id: String) -> void:
	_apply_toggle_level(level_id)


func _apply_toggle_level(level_id: String) -> void:
	ProgressManager.debug_toggle_level(level_id)
