extends Node

signal progress_changed

const LEVEL_ORDER: Array[String] = [
	"Tutorial",
	"Vivaldi_four_seasons",
	"Seven_nation_army"
]

var completed: Array[String] = []

func is_unlocked(level: String) -> bool:
	var i := LEVEL_ORDER.find(level)
	if i == -1:
		return false
	if i == 0:
		return true
	return LEVEL_ORDER[i - 1] in completed

func complete_level(level: String) -> void:
	if level in completed:
		return
	completed.append(level)
	progress_changed.emit()

func reset_progress() -> void:
	completed.clear()
	progress_changed.emit()
