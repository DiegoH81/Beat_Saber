extends CanvasLayer

@export var turret_controller: TurrentController
@export var shield_buttons_container: GridContainer
@export var turret_buttons_container: HBoxContainer
@export var shot_button: Button
@export var generator: Generator
@export var ammo: Label
var _shooting: bool = false
	
var _blink_tween: Tween

func _ready() -> void:
	_connect_shield_buttons()
	_connect_turrets_buttons()
	turret_controller.ammo_changed.connect(_on_ammo_changed)
	_on_ammo_changed.call_deferred(turret_controller.ammo, turret_controller.max_ammo)
	if generator:
		generator.beam_warning.connect(_on_beam_warning)
	shot_button.button_down.connect(func(): _shooting = true)
	shot_button.button_up.connect(func(): _shooting = false)
func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo.text = "%d/%d" % [current, max_ammo]

func _process(_delta: float) -> void:
	if _shooting:
		turret_controller.raycast_from_camera()

func _connect_shield_buttons() -> void:
	for i in range(shield_buttons_container.get_child_count()):
		var button := shield_buttons_container.get_child(i) as Button

		if button == null:
			print("Shields: fallo al conectar")
			continue

		button.pressed.connect(_on_shield_button_pressed.bind(i))

func _connect_turrets_buttons() -> void:
	for i in range(turret_buttons_container.get_child_count()):
		var button := turret_buttons_container.get_child(i) as Button

		if button == null:
			print("Turrets: fallo al conectar")
			continue

		button.pressed.connect(_on_turret_button_pressed.bind(i))

func _on_shield_button_pressed(index: int) -> void:
	turret_controller.active_shield(index)

func _on_turret_button_pressed(index: int) -> void:
	turret_controller.changed_to_turret(index)

func _on_beam_warning(lane: int, phase: int) -> void:

	if _blink_tween:
		_blink_tween.kill()
	for c in shield_buttons_container.get_children():
		var btn := c as Button
		if btn:
			btn.modulate = Color.WHITE
	if phase == 2 or lane < 0 or lane >= shield_buttons_container.get_child_count():
			return

	var b := shield_buttons_container.get_child(lane) as Button

	if b == null:
		return
	var color := Color(3, 3, 0) if phase == 0 else Color(4, 0, 0)
	var t := 0.25 if phase == 0 else 0.08 # el rojo parpadea más rápido
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(b, "modulate", color, t)
	_blink_tween.tween_property(b, "modulate", Color.WHITE, t)
