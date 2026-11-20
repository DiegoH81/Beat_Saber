extends CanvasLayer

@export var turret_controller: TurrentController
@export var shield_buttons_container: GridContainer
@export var turret_buttons_container: HBoxContainer
@export var shot_button: Button
@export var generator: Generator
@export var ammo: Label
@export var ammo_bar: ProgressBar
@export var buff: Label
@export var buff_card: Panel
@export var buff_icon: Control
@export var buff_display_time: float = 1.5
@export var buff_fade_time: float = 0.5

var _shooting: bool = false
	
var _blink_tween: Tween
var _buff_tween: Tween
var _buff_card_y: float
var _buff_style: StyleBoxFlat
var _buff_kind: String = ""

func _ready() -> void:
	_connect_shield_buttons()
	_connect_turrets_buttons()
	turret_controller.turret_changed.connect(_on_turret_changed)
	_on_turret_changed(turret_controller.current_index)
	turret_controller.ammo_changed.connect(_on_ammo_changed)
	turret_controller.buff_collected.connect(_on_buff_collected)
	_on_ammo_changed.call_deferred(turret_controller.ammo, turret_controller.max_ammo)
	_buff_card_y = buff_card.position.y
	_buff_style = buff_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	buff_card.add_theme_stylebox_override("panel", _buff_style)
	buff_icon.draw.connect(_draw_buff_icon)
	if generator:
		generator.beam_warning.connect(_on_beam_warning)
	shot_button.button_down.connect(func(): _shooting = true)
	shot_button.button_up.connect(func(): _shooting = false)

func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo.text = "%d/%d" % [current, max_ammo]
	ammo_bar.max_value = max_ammo
	ammo_bar.value = current

func _on_turret_changed(index: int) -> void:
	for i in range(turret_buttons_container.get_child_count()):
		var button := turret_buttons_container.get_child(i) as Button
		if button:
			button.set_pressed_no_signal(i == index)

func _on_buff_collected(kind: String, ammo_gained: int) -> void:
	var accent := Color(0.83, 0.67, 0.48)
	_buff_kind = kind
	match kind:
		"ammo":
			accent = Color(0.65, 0.75, 0.63)
			buff.text = "+%d munición" % ammo_gained if ammo_gained > 0 else "Munición al máximo"
		"rate":
			if is_equal_approx(turret_controller.fire_cooldown, turret_controller.min_fire_cooldown):
				buff.text = "Cadencia al máximo"
			else:
				buff.text = "Cadencia aumentada"
		"score":
			accent = Color(0.63, 0.75, 0.96)
			buff.text = "P1 · Puntos ×2 · %d s" % (ScoreManager.DOUBLE_SCORE_DURATION_MS / 1000)
		_:
			buff.text = kind

	if _buff_tween:
		_buff_tween.kill()
	_buff_style.border_color = accent
	buff_icon.modulate = accent
	buff_icon.queue_redraw()
	buff_card.position.y = _buff_card_y + 12.0
	buff_card.modulate.a = 0.0
	buff_card.show()
	_buff_tween = create_tween()
	_buff_tween.tween_property(buff_card, "position:y", _buff_card_y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_buff_tween.parallel().tween_property(buff_card, "modulate:a", 1.0, 0.12)
	_buff_tween.tween_interval(buff_display_time)
	_buff_tween.tween_property(buff_card, "modulate:a", 0.0, buff_fade_time)
	_buff_tween.tween_callback(buff_card.hide)

func _draw_buff_icon() -> void:
	if _buff_kind == "score":
		buff_icon.draw_line(Vector2(5, 6), Vector2(19, 18), Color.WHITE, 2.0, true)
		buff_icon.draw_line(Vector2(19, 6), Vector2(5, 18), Color.WHITE, 2.0, true)
		return
	for i in range(3):
		var x := 2.0 + i * 7.0
		if _buff_kind == "ammo":
			var cartridge := PackedVector2Array([
				Vector2(x, 20), Vector2(x, 8), Vector2(x + 2, 4),
				Vector2(x + 4, 8), Vector2(x + 4, 20), Vector2(x, 20),
			])
			buff_icon.draw_polyline(cartridge, Color.WHITE, 1.4, true)
		else:
			var height := 6.0 + i * 5.0
			buff_icon.draw_rect(Rect2(x, 20.0 - height, 4.0, height), Color.WHITE)

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
