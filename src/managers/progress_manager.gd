extends Node

signal progress_changed

const LEVEL_ORDER: Array[String] = [
	"Tutorial",
	"Vivaldi_four_seasons",
	"Sing_Sing_Sing",
	"Seven_nation_army"
]

var completed: Array[String] = []

var debug_overrides: Dictionary = {}


func is_unlocked(level: String) -> bool:
	if level == "Tutorial":
		return true
	if debug_overrides.has(level):
		return debug_overrides[level]
	var i := LEVEL_ORDER.find(level)
	if i == -1:
		return false
	if i == 0:
		return true
	return LEVEL_ORDER[i - 1] in completed
	
func debug_toggle_level(level: String) -> void:
	debug_overrides[level] = not is_unlocked(level)
	progress_changed.emit()

func complete_level(level: String) -> void:
	if level in completed:
		return
	completed.append(level)
	progress_changed.emit()

func reset_progress() -> void:
	completed.clear()
	progress_changed.emit()
