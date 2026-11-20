extends Node3D
class_name Level

const P2_POPUP_DURATION := 4.5
const P2_INTRO_DURATION := P2_POPUP_DURATION * 2.0

@export var player_vr: XROrigin3D
@export var generator: Generator
@export var ambient: WorldEnvironment
@export var next_level_id: String
@export var own_id: String
@export var spawn: Node3D
@export var pause_menu: Node3D
@export var turret_controller: TurrentController
@export var p2_tutorial_popup: PopUp2D
var number: int = 0

@export var song_name: String


func _ready() -> void:
	if generator:
		generator.set_physics_process(false)
		if turret_controller:
			generator.turret_controller = turret_controller
			turret_controller.place_shields_on_lanes(generator.points, -generator.global_basis.z.normalized())
			if not multiplayer.is_server():
				generator.shield_blocked.connect(turret_controller.play_shield_impact)
	ScoreManager.reset_score()
	ScoreManager.misses_updated.connect(_on_misses_updated)
	_setup_turrets.call_deferred()

func _setup_turrets() -> void:
	print("turret_controller: ", turret_controller)
	print("is_server: ", multiplayer.is_server())
	if not is_instance_valid(turret_controller):
		push_warning("Level %s: turret_controller no asignado" % own_id)
		return
	turret_controller.changed_to_turret(0, not multiplayer.is_server())

func _enter_tree() -> void:
	AudioManager.prepare_music(song_name)
	VisualManager.register_world_env(ambient)

func start_song(special_indices: PackedInt32Array) -> void:
	var p2_tutorial := is_instance_valid(p2_tutorial_popup) and not multiplayer.get_peers().is_empty()
	if is_instance_valid(player_vr):
		player_vr.is_paused = false
		if pause_menu:
			player_vr.pause.connect(pause_menu.pause)
	AudioManager.resume_music()
	AudioManager.play_prepared_music()
	if generator:
		generator.start_song(special_indices, P2_INTRO_DURATION + 0.3 if p2_tutorial else -1.0)
		if turret_controller:
			turret_controller.start_station_attacks(generator)
	var powerups := get_node_or_null("GeneratorBuff") as PowerupGenerator
	if powerups and turret_controller and not turret_controller.turrets.is_empty():
		powerups.start_spawning(
			turret_controller.turrets[0],
			P2_POPUP_DURATION if p2_tutorial else 0.0,
			P2_INTRO_DURATION if p2_tutorial else 0.0)
	if p2_tutorial and not multiplayer.is_server():
		_show_p2_tutorial(powerups)

func _show_p2_tutorial(powerups: PowerupGenerator) -> void:
	var examples: HBoxContainer
	if powerups:
		var models: Array[Node3D] = []
		for kind in PowerupGenerator.POWERUPS:
			models.append(powerups.preview_model(kind))
		examples = p2_tutorial_popup.model_row(models, PackedStringArray(["Balas", "Cadencia", "Puntos dobles para P1"]))
	await p2_tutorial_popup.show_message(
		"Dorados y potenciadores", "Usa clic izquierdo para disparar.",
		P2_POPUP_DURATION, examples)
	await p2_tutorial_popup.show_message(
		"Escudos y camaras", "Sigue la casilla o el numero que parpadea.",
		P2_POPUP_DURATION, p2_tutorial_popup.control_rows({
			"Alt y clic": "Cubre el carril del rayo",
			"Teclas 1 2 3": "Cambia de torreta",
		}))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p_button"):
		if number == 0:
			VisualManager.change_shader("classic")
			number=1
		elif number == 1:
			VisualManager.change_shader("toon")
			number=2
		elif number == 2:
			VisualManager.change_shader("new_mill")
			number=3
		elif number == 3:
			VisualManager.change_shader("new_dec")
			number=0

	if event.is_action_pressed("f_button"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_misses_updated(value: float) -> void:
	if value >= ScoreManager.MAX_MISSES:
		ScoreManager.misses_updated.disconnect(_on_misses_updated)
		_restart_level()

func _to_next_level() -> void:
	ProgressManager.complete_level(own_id)
	if not next_level_id.is_empty():
		SceneManager.request_level(next_level_id)
		return
	SceneManager.request_menu()


func _restart_level() -> void:
	SceneManager.request_level.call_deferred(own_id)
