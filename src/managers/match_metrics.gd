extends Node

const LOG_PATH := "user://metricas_partidas.jsonl"

var _menu_started_ms := -1
var _play_pressed_ms := -1
var _level_selected_ms := -1
var _pending_ip_seconds := -1.0
var _submission_seconds := -1.0
var _song_started_ms := -1
var _round: Dictionary = {}
var _write_error_reported := false


func open_host_menu() -> void:
	if multiplayer.is_server():
		_menu_started_ms = Time.get_ticks_msec()
		_play_pressed_ms = -1
		_level_selected_ms = -1


func press_play() -> void:
	if multiplayer.is_server() and _menu_started_ms >= 0 and _play_pressed_ms < 0:
		_play_pressed_ms = Time.get_ticks_msec()


func select_level() -> void:
	if _menu_started_ms >= 0:
		_level_selected_ms = Time.get_ticks_msec()


func remember_ip_submission(seconds: float) -> void:
	_submission_seconds = seconds


func send_ip_timing() -> void:
	if _submission_seconds >= 0.0:
		_receive_ip_timing.rpc_id(1, _submission_seconds)
		_submission_seconds = -1.0


@rpc("any_peer", "call_remote", "reliable")
func _receive_ip_timing(seconds: float) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() <= 1:
		return
	if not is_finite(seconds) or seconds < 0.0:
		return
	if _round.is_empty():
		_pending_ip_seconds = seconds
	elif _round["p2_ip_s"] == null:
		_round["p2_ip_s"] = seconds
		_append_snapshot()


func begin_round(level_id: String) -> void:
	finish_round("reemplazada")
	_song_started_ms = -1
	_round = {
		"id_partida": Crypto.new().generate_random_bytes(12).hex_encode(),
		"inicio_utc": Time.get_datetime_string_from_system(true) + "Z",
		"nivel": level_id,
		"estado": "cargando",
		"p1_play_s": _seconds_between(_menu_started_ms, _play_pressed_ms),
		"p1_elegir_nivel_s": _seconds_between(_play_pressed_ms, _level_selected_ms),
		"p1_primer_bloque_s": null,
		"p2_ip_s": _pending_ip_seconds if _pending_ip_seconds >= 0.0 else null,
		"p2_cadencia_s": null,
		"p2_puntos_dobles_s": null,
		"p2_balas_s": null,
		"p2_primer_amarillo_s": null,
		"primera_falla_s": null,
		"primera_falla_jugador": null,
		"primera_falla_tipo": null,
		"fallos_bloque_p1": 0,
		"fallos_amarillo_p2": 0,
		"fallos_laser_p2": 0,
		"fallos_laser_sin_p2": 0,
		"fallos_totales": 0,
		"max_contador_fallos": 0.0,
		"combo_maximo": 0,
	}
	_menu_started_ms = -1
	_play_pressed_ms = -1
	_level_selected_ms = -1
	_pending_ip_seconds = -1.0
	_append_snapshot()


func start_song() -> void:
	if _round.is_empty():
		return
	_song_started_ms = Time.get_ticks_msec()
	_round["estado"] = "en_juego"
	_append_snapshot()


func first_action(metric: String) -> void:
	if _song_started_ms >= 0 and _round.get(metric) == null:
		_round[metric] = _song_seconds()
		_append_snapshot()


func record_combo(combo: int) -> void:
	if _song_started_ms >= 0 and combo > _round["combo_maximo"]:
		_round["combo_maximo"] = combo
		_append_snapshot()


func record_failure(player: String, kind: String, counter: float) -> void:
	if _song_started_ms < 0:
		return
	if _round["primera_falla_s"] == null:
		_round["primera_falla_s"] = _song_seconds()
		_round["primera_falla_jugador"] = player
		_round["primera_falla_tipo"] = kind
	var key := "fallos_%s_%s" % [kind, player.to_lower()]
	_round[key] += 1
	_round["fallos_totales"] += 1
	_round["max_contador_fallos"] = maxf(_round["max_contador_fallos"], counter)
	_append_snapshot()


func mark_song_ended() -> void:
	if not _round.is_empty():
		_round["estado"] = "cancion_terminada"
		_append_snapshot()


func finish_round(reason: String) -> void:
	if _round.is_empty():
		return
	if _round["estado"] == "cancion_terminada" and reason != "limite_de_fallos":
		reason = "completada"
	_round["estado"] = reason
	_append_snapshot(true)
	_round.clear()
	_song_started_ms = -1


func reset_session() -> void:
	finish_round("reinicio")
	_menu_started_ms = -1
	_play_pressed_ms = -1
	_level_selected_ms = -1
	_pending_ip_seconds = -1.0
	_submission_seconds = -1.0


func _seconds_between(start_ms: int, end_ms: int) -> Variant:
	if start_ms < 0 or end_ms < start_ms:
		return null
	return (end_ms - start_ms) / 1000.0


func _song_seconds() -> float:
	return (Time.get_ticks_msec() - _song_started_ms) / 1000.0


func _append_snapshot(final := false) -> void:
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE
	var file := FileAccess.open(LOG_PATH, mode)
	if file == null:
		if not _write_error_reported:
			push_error("No se pudieron guardar las métricas en %s (error %d)." %
				[ProjectSettings.globalize_path(LOG_PATH), FileAccess.get_open_error()])
			_write_error_reported = true
		return
	_write_error_reported = false
	file.seek_end()
	var snapshot := _round.duplicate()
	snapshot["final"] = final
	file.store_line(JSON.stringify(snapshot))
	file.flush()


func _exit_tree() -> void:
	finish_round("aplicacion_cerrada")
