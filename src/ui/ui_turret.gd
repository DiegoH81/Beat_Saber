extends CanvasLayer

@export var turret_controller: TurrentController
@export var shield_buttons_container: GridContainer
@export var turret_buttons_container: HBoxContainer
@export var shot_button: Button
@export var generator: Generator
@export var ammo: Label
@export var buff: Label
@export var buff_display_time: float = 0.75
@export var buff_fade_time: float = 0.32

var _shooting: bool = false
	
var _blink_tween: Tween
var _buff_tween: Tween
@onready var _buff_rest_y: float = buff.position.y

func _ready() -> void:
	_connect_shield_buttons()
	turret_controller.shield_changed.connect(_on_shield_changed)
	_connect_turrets_buttons()
	turret_controller.turret_changed.connect(_on_turret_changed)
	_on_turret_changed(turret_controller.current_index)
	turret_controller.ammo_changed.connect(_on_ammo_changed)
	turret_controller.buff_collected.connect(_on_buff_collected)
	_on_ammo_changed.call_deferred(turret_controller.ammo, turret_controller.max_ammo)
	if generator:
		generator.beam_warning.connect(_on_beam_warning)
	shot_button.button_down.connect(func(): _shooting = true)
	shot_button.button_up.connect(func(): _shooting = false)

func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo.text = "%d/%d" % [current, max_ammo]

func _on_turret_changed(index: int) -> void:
	for i in range(turret_buttons_container.get_child_count()):
		var button := turret_buttons_container.get_child(i) as Button
		if button:
			button.set_pressed_no_signal(i == index)

func _on_buff_collected(kind: String, ammo_gained: int) -> void:
	var accent := Color(0.96, 0.77, 0.53)
	match kind:
		"ammo":
			accent = Color(0.73, 0.90, 0.59)
			buff.text = "+%d balas" % ammo_gained if ammo_gained > 0 else "Munición llena"
		"rate":
			if is_equal_approx(turret_controller.fire_cooldown, turret_controller.min_fire_cooldown):
				buff.text = "Cadencia al máximo"
			else:
				buff.text = "Cadencia +"
		"score":
			accent = Color(0.65, 0.80, 1.0)
			buff.text = "×2 puntos"
		_:
			buff.text = kind

	if _buff_tween:
		_buff_tween.kill()
	buff.add_theme_color_override("font_color", accent)
	buff.modulate.a = 0.0
	buff.position.y = _buff_rest_y + 10.0
	buff.show()
	_buff_tween = create_tween()
	_buff_tween.tween_property(buff, "position:y", _buff_rest_y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_buff_tween.parallel().tween_property(buff, "modulate:a", 1.0, 0.12)
	_buff_tween.tween_interval(buff_display_time)
	_buff_tween.tween_property(buff, "modulate:a", 0.0, buff_fade_time)
	_buff_tween.parallel().tween_property(buff, "position:y", _buff_rest_y - 13.0, buff_fade_time)
	_buff_tween.tween_callback(buff.hide)

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
		button.disabled = turret_controller.is_shield_active(i)

func _connect_turrets_buttons() -> void:
	for i in range(turret_buttons_container.get_child_count()):
		var button := turret_buttons_container.get_child(i) as Button

		if button == null:
			print("Turrets: fallo al conectar")
			continue

		button.pressed.connect(_on_turret_button_pressed.bind(i))

func _on_shield_button_pressed(index: int) -> void:
	turret_controller.active_shield(index)

func _on_shield_changed(index: int, active: bool) -> void:
	if index >= 0 and index < shield_buttons_container.get_child_count():
		var button := shield_buttons_container.get_child(index) as Button
		if button:
			button.disabled = active

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
	var t := 0.25 if phase == 0 else 0.08
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(b, "modulate", color, t)
	_blink_tween.tween_property(b, "modulate", Color.WHITE, t)
