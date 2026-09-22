extends Node

@export_category("Dependencies")
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer3D] = []
const SFX_POOL_SIZE: int = 12

const path: String = "res://levels_data/data/"

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music"
	
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	
	

func play_music(id: String) -> void:
	music_player.stream = load(path + id + "/song.ogg")
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func play_sfx(id: String, position: Vector3 = Vector3.ZERO) -> AudioStreamPlayer3D:
	var player : AudioStreamPlayer3D = get_free_sfx_player()
	if player == null:
		return null

	player.stream = load(path + id + ".wav")
	player.global_position = position
	player.play()
	return player

func get_free_sfx_player() -> AudioStreamPlayer3D:
	for p in sfx_players:
		if not p.playing:
			return p
	return sfx_players[0]
