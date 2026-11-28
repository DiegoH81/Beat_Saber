extends Node

signal hit_registered(new_score: int)
signal combo_updated(new_combo: int)
signal multiplier_updated(progress: float, multiplier_level: int, just_leveled_up: bool)
signal misses_updated(new_misses: float)

const MAX_MISSES: int = 20
const DOUBLE_SCORE_DURATION_MS: int = 5000
const BEAM_MISS_COST: float = 0.25

var current_score: int = 0
var current_combo: int = 0
var misses: float = 0.0


var current_multiplier: float = 1.0
var current_multiplier_hits: int = 0
var multiplier_level: int = 1
var _double_score_until: int = 0


func activate_double_score() -> void:
	_double_score_until = Time.get_ticks_msec() + DOUBLE_SCORE_DURATION_MS

func add_hit(amount: int = 1) -> void:
	current_combo += 1
	if multiplayer.is_server():
		MatchMetrics.first_action("p1_primer_bloque_s")
		MatchMetrics.record_combo(current_combo)
	current_multiplier_hits += 1
	
	if misses > 0:
		misses = 0
		misses_updated.emit(misses)
		
	print("HIT combo=", current_combo + 1)

	
	var required_hits: int = int(pow(2, multiplier_level))
	var progress: float = float(current_multiplier_hits) / float(required_hits)
	
	var just_leveled_up: bool = false
	
	if current_multiplier_hits >= required_hits:
		current_multiplier_hits = 0
		multiplier_level += 1
		current_multiplier = float(multiplier_level)
		progress = 1.0
		just_leveled_up = true
	else:
		current_multiplier += 1.0 / float(required_hits)
	
	var points := int(amount * current_multiplier)
	if Time.get_ticks_msec() < _double_score_until:
		points *= 2
	current_score += points
	
	hit_registered.emit(current_score)
	combo_updated.emit(current_combo)
	multiplier_updated.emit(progress, multiplier_level, just_leveled_up)
	_broadcast_state(progress, just_leveled_up)

func register_miss(special: bool = false) -> void:

	misses += 1
	if multiplayer.is_server():
		if special:
			MatchMetrics.record_failure("P2", "amarillo", misses)
		else:
			MatchMetrics.record_failure("P1", "bloque", misses)
	current_combo = 0
	current_multiplier_hits = 0
	
	print("MISS", misses)
	
	multiplier_level = max(1, multiplier_level - 1)
	current_multiplier = float(multiplier_level)
	
	misses_updated.emit(misses)
	combo_updated.emit(current_combo)
	multiplier_updated.emit(0.0, multiplier_level, false)
	_broadcast_state(0.0, false)

func register_beam_hit() -> void:
	misses += BEAM_MISS_COST
	if multiplayer.is_server():
		var player := "P2" if not multiplayer.get_peers().is_empty() else "sin_p2"
		MatchMetrics.record_failure(player, "laser", misses)
	misses_updated.emit(misses)
	_broadcast_state(float(current_multiplier_hits) / pow(2, multiplier_level), false)

func reset_score() -> void:
	_double_score_until = 0
	current_score = 0
	current_combo = 0
	misses = 0
	current_multiplier_hits = 0
	multiplier_level = 1
	current_multiplier = 1.0
	
	misses_updated.emit(misses)
	hit_registered.emit(current_score)
	combo_updated.emit(current_combo)
	multiplier_updated.emit(0.0, multiplier_level, false)


# El servidor es la autoridad del puntaje: después de cada cambio le manda el
# estado completo a los clientes para que el P2 vea exactamente lo mismo.
func _broadcast_state(progress: float, just_leveled_up: bool) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() 			or multiplayer.get_peers().is_empty():
		return
	_apply_state.rpc(current_score, current_combo, misses, multiplier_level,
		current_multiplier, current_multiplier_hits, progress, just_leveled_up)

@rpc("authority", "call_remote", "reliable")
func _apply_state(score: int, combo: int, new_misses: float, level: int,
		multiplier: float, multiplier_hits: int, progress: float, just_leveled_up: bool) -> void:
	var score_changed := score != current_score
	var combo_changed := combo != current_combo
	var misses_changed := not is_equal_approx(new_misses, misses)
	current_score = score
	current_combo = combo
	misses = new_misses
	multiplier_level = level
	current_multiplier = multiplier
	current_multiplier_hits = multiplier_hits

	if misses_changed:
		misses_updated.emit(misses)
	if score_changed:
		hit_registered.emit(current_score)
	if combo_changed:
		combo_updated.emit(current_combo)
	multiplier_updated.emit(progress, multiplier_level, just_leveled_up)
