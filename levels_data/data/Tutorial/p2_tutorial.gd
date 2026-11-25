extends Node3D

const PAGE_DURATION := 4.0
const INTRO_DURATION := PAGE_DURATION * 2.0
const TUTORIAL_CARDS := preload("res://levels_data/data/Tutorial/p2_tutorial_cards.tscn")

@onready var _level := get_parent() as Level

func _ready() -> void:
	_level.song_start_sequence = _start_song

func _start_song(special_indices: PackedInt32Array) -> void:
	if multiplayer.get_peers().is_empty():
		_level.start_gameplay(special_indices)
		return

	_level.start_gameplay(special_indices, INTRO_DURATION + 0.3, PAGE_DURATION, INTRO_DURATION)
	if not multiplayer.is_server():
		_show_cards()

func _show_cards() -> void:
	var hud := _level.get_node_or_null("UITurret") as CanvasLayer
	var hud_was_visible := hud != null and hud.visible
	if hud_was_visible:
		hud.hide()
	var cards := TUTORIAL_CARDS.instantiate()
	add_child(cards)
	await get_tree().create_timer(PAGE_DURATION, false).timeout
	cards.show_page(1)
	await get_tree().create_timer(PAGE_DURATION, false).timeout
	cards.queue_free()
	if hud_was_visible and is_instance_valid(hud):
		hud.show()
