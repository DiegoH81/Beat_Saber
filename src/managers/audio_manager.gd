extends Node

@export_category("Dependencies")
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer3D] = []
const SFX_POOL_SIZE: int = 12

var _music_paused: bool = false

var music_level: int = 5
var sfx_level: int = 3
var music_bus: int
var sfx_bus: int


const path: String = "res://levels_data/data/"

func _ready() -> void:
	music_bus = AudioServer.get_bus_index("Music")
	sfx_bus = AudioServer.get_bus_index("SFX")
	
	music_player = AudioStreamPlayer.new()
	
	add_child(music_player)
	music_player.bus = "Music"
	
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		
		p.attenuation_filter_cutoff_hz = 20500
		p.attenuation_filter_db = 0
		
		add_child(p)
		sfx_players.append(p)
	
func play_music(id: String) -> void:
	music_player.stream = load(path + id + "/song.ogg")
	music_player.play()
	music_player.stream_paused = _music_paused

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
	

func _update_music_bus() -> void:
	var norm = music_level / 10.0
	AudioServer.set_bus_mute(music_bus, music_level <= 0)
	if music_level > 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(norm))

func _update_sfx_bus() -> void:
	var norm = sfx_level / 10.0
	AudioServer.set_bus_mute(sfx_bus, sfx_level <= 0)
	if sfx_level > 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(norm))

func get_music_level() -> int:
	return music_level
	
func get_sfx_level() -> int:
	return sfx_level

func increase_music() -> int:
	music_level = clampi(music_level + 1, 0, 10)
	_update_music_bus()
	return music_level

func decrease_music() -> int:
	music_level = clampi(music_level - 1, 0, 10)
	_update_music_bus()
	return music_level

func increase_sfx() -> int:
	sfx_level = clampi(sfx_level + 1, 0, 10)
	_update_sfx_bus()
	return sfx_level

func decrease_sfx() -> int:
	sfx_level = clampi(sfx_level - 1, 0, 10)
	_update_sfx_bus()
	return sfx_level

func pause_music() -> void:
	_music_paused = true
	music_player.stream_paused = true

func resume_music() -> void:
	_music_paused = false
	music_player.stream_paused = false

func get_music_position() -> float:
	return music_player.get_playback_position()
