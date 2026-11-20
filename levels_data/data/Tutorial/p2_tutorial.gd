extends Node3D

const PAGE_DURATION := 4.0
const INTRO_DURATION := PAGE_DURATION * 2.0

@export var powerups: PowerupGenerator

@onready var _level := get_parent() as Level
@onready var _powerup_text: Node3D = $PowerupText
@onready var _controls: MeshInstance3D = $Controls

func _ready() -> void:
	hide()
	_level.song_start_sequence = _start_song

func _start_song(special_indices: PackedInt32Array) -> void:
	if multiplayer.get_peers().is_empty():
		_level.start_gameplay(special_indices)
		return

	_level.start_gameplay(special_indices, INTRO_DURATION + 0.3, PAGE_DURATION, INTRO_DURATION)
	if not multiplayer.is_server():
		_show_text()

func _show_text() -> void:
	if powerups:
		for i in PowerupGenerator.POWERUPS.size():
			var model := powerups.preview_model(PowerupGenerator.POWERUPS[i])
			_powerup_text.get_node("Examples").get_child(i).add_child(model)
			model.position.y = 0.32
			model.scale = Vector3.ONE * 0.25

	_powerup_text.show()
	_controls.hide()
	show()
	await get_tree().create_timer(PAGE_DURATION, false).timeout
	_powerup_text.hide()
	_controls.show()
	await get_tree().create_timer(PAGE_DURATION, false).timeout
	hide()
