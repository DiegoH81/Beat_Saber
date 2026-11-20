extends Node

const POPUP_DURATION := 4.0
const INTRO_DURATION := POPUP_DURATION * 2.0

@export var popup: PopUp2D
@export var powerups: PowerupGenerator

@onready var _level := get_parent() as Level

func _ready() -> void:
	_level.song_start_sequence = _start_song

func _start_song(special_indices: PackedInt32Array) -> void:
	if not is_instance_valid(popup) or multiplayer.get_peers().is_empty():
		_level.start_gameplay(special_indices)
		return

	_level.start_gameplay(special_indices, INTRO_DURATION + 0.3, POPUP_DURATION, INTRO_DURATION)
	if not multiplayer.is_server():
		_show_messages()

func _show_messages() -> void:
	var examples: HBoxContainer
	if powerups:
		var models: Array[Node3D] = []
		for kind in PowerupGenerator.POWERUPS:
			models.append(powerups.preview_model(kind))
		examples = popup.model_row(models, PackedStringArray(["Balas", "Cadencia", "Puntos dobles para P1"]))

	await popup.show_message(
		"Dorados y potenciadores", "Usa clic izquierdo para disparar.",
		POPUP_DURATION, examples)
	await popup.show_message(
		"", "Sigue la casilla o el numero que parpadea.",
		POPUP_DURATION, popup.control_rows({
			"Alt y clic": "Cubre el carril del rayo",
			"Teclas 1 2 3": "Cambia de torreta",
		}))
