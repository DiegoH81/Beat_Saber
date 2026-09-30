extends Node

signal hit_registered(new_score: int)
signal combo_updated(new_combo: int)
signal multiplier_updated(new_multiplier: float, multiplier_level: int)

var current_score: int = 0
var current_combo: int = 0

var current_multiplier: float = 1.0
var current_multiplier_hits: int = 0
var multiplier_level: int = 1

func add_hit(amount: int = 1) -> void:
	current_combo += 1
	current_multiplier_hits += 1
	
	var required_hits: int = int(pow(2, multiplier_level))
	
	current_multiplier += 1.0 / float(required_hits)
	
	if current_multiplier_hits >= required_hits:
		current_multiplier_hits = 0
		multiplier_level += 1
	
	
	current_score += int(amount * current_multiplier)
	
	hit_registered.emit(current_score)
	combo_updated.emit(current_combo)
	multiplier_updated.emit(current_multiplier, multiplier_level)

func register_miss() -> void:
	current_combo = 0
	current_multiplier_hits = 0
	
	multiplier_level -= 1
	current_multiplier -= 1.0
	
	if multiplier_level < 1:
		multiplier_level = 1
	if current_multiplier < 1.0:
		current_multiplier = 1.0
	
	combo_updated.emit(current_combo)
	multiplier_updated.emit(current_multiplier, multiplier_level)

func reset_score() -> void:
	current_score = 0
	current_combo = 0
	current_multiplier_hits = 0
	multiplier_level = 1
	current_multiplier = 1.0
	
	hit_registered.emit(current_score)
	combo_updated.emit(current_combo)
	multiplier_updated.emit(current_multiplier, multiplier_level)
