extends Node
class_name AudioManager

@export_category("Dependencies")
@export var music_player: AudioStreamPlayer
@export var sfx_player: AudioStreamPlayer

const path: String = "res://levels_data/music/"

func _ready() -> void:
	music_player.bus = "Music"
	sfx_player.bus = "SFX"

func play_music(id: String) -> void:
	music_player.stream = load(path + id)
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func play_sfx(id: String) -> void:
	sfx_player.stream = load(path + id)
	sfx_player.play()

func stop_sfx() -> void:
	sfx_player.stop()
