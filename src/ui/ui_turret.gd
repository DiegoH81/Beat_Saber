@tool
extends CanvasLayer

const ShieldCutEffect := preload("res://src/ui/shield_cut_effect.gd")
const SHIELD_DARKENING := {&"normal": 0.57, &"hover": 0.51, &"pressed": 0.51, &"disabled": 0.60}

@export var turret_controller: TurrentController
@export var shield_buttons_container: GridContainer
@export var turret_buttons_container: HBoxContainer
@export var shot_button: Button
@export var generator: Generator
@export var buff: Label
@export var buff_display_time: float = 0.75
@export var buff_fade_time: float = 0.32
@export_color_no_alpha var shield_color := Color(0.64, 0.24, 1.0):
	set(value):
		shield_color = value
		if is_node_ready():
			_apply_shield_color()

var _shooting: bool = false
	
var _blink_tween: Tween
var _warning_button: Button
var _station_flash: ColorRect
var _station_flash_tween: Tween
var _buff_tween: Tween
var _danger: Control
var _danger_tween: Tween
var _danger_target := -1
var _buff_rest_y: float

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		_apply_shield_color()
		return

	_buff_rest_y = buff.position.y
	_keep_single_shield_button()
	_connect_shield_buttons()
	_apply_shield_color()
	turret_controller.shield_changed.connect(_on_shield_changed)
	_connect_turrets_buttons()
	_station_flash = ColorRect.new()
	_station_flash.color = Color(1.0, 0.04, 0.08, 0.0)
	_station_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_station_flash)
	_station_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_danger_warning()
	turret_controller.turret_changed.connect(_on_turret_changed)
	turret_controller.station_attack_changed.connect(_on_station_attack_changed)
	_on_turret_changed(turret_controller.current_index)
	turret_controller.buff_collected.connect(_on_buff_collected)
	if generator:
		generator.beam_warning.connect(_on_beam_warning)
	shot_button.button_down.connect(func(): _shooting = true)
	shot_button.button_up.connect(func(): _shooting = false)

# Antes había un botón por fila (Q/W/E); ahora un solo escudo con Espacio.
# Se resuelve en código porque los niveles heredados sobreescriben los botones.
func _keep_single_shield_button() -> void:
	shield_buttons_container.columns = 1
	var box := shield_buttons_container.get_parent() as BoxContainer
	if box:
		box.alignment = BoxContainer.ALIGNMENT_END
	for i in range(shield_buttons_container.get_child_count() - 1, 0, -1):
		var extra := shield_buttons_container.get_child(i)
		shield_buttons_container.remove_child(extra)
		extra.queue_free()
	var button := shield_buttons_container.get_child(0) as Button
	if button:
		button.text = "ESPACIO"

func _on_turret_changed(index: int) -> void:
	for i in range(turret_buttons_container.get_child_count()):
		var button := turret_buttons_container.get_child(i) as Button
		if button:
			button.set_pressed_no_signal(i == index)
	# Si el P2 ya se cambió de torreta, el aviso grande desaparece.
	if _danger:
		_danger.visible = _danger_target >= 0 and _danger_target == index

func _on_station_attack_changed(index: int, state: TurrentController.StationState) -> void:
	if index < 0 or index >= turret_buttons_container.get_child_count():
		return
	var button := turret_buttons_container.get_child(index) as Button
	if button == null:
		return
	if state == TurrentController.StationState.WARNING:
		_show_danger(index, button)
		return
	_hide_danger(button)
	button.disabled = state == TurrentController.StationState.OFFLINE
	if not button.disabled:
		return
	if _station_flash_tween:
		_station_flash_tween.kill()
	_station_flash.color.a = 0.36
	_station_flash_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_station_flash_tween.tween_property(_station_flash, "color:a", 0.0, 0.32)


func _build_danger_warning() -> void:
	_danger = VBoxContainer.new()
	_danger.name = "TurretDanger"
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger.visible = false
	(_danger as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	_danger.add_theme_constant_override("separation", 0)
	add_child(_danger)
	_danger.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_danger.offset_top = 110.0
	_danger.offset_left = -300.0
	_danger.offset_right = 300.0

	_danger_text(_danger, 72).text = "PELIGRO"
	_danger_text(_danger, 30).text = "CAMBIA DE POSICIÓN"

func _danger_text(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.15))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.0, 0.01, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label

func _show_danger(index: int, _button: Button) -> void:
	_danger_target = index
	_danger.visible = index == turret_controller.current_index
	_danger.modulate.a = 1.0
	if _danger_tween:
		_danger_tween.kill()
	_danger_tween = create_tween().set_loops()
	_danger_tween.tween_property(_danger, "modulate:a", 0.2, 0.18)
	_danger_tween.tween_property(_danger, "modulate:a", 1.0, 0.18)

func _hide_danger(_button: Button) -> void:
	_danger_target = -1
	if _danger_tween:
		_danger_tween.kill()
	_danger.visible = false

func _on_buff_collected(kind: String, ammo_gained: int) -> void:
	var accent := Color(0.96, 0.77, 0.53)
	match kind:
		"ammo":
			accent = Color(0.73, 0.90, 0.59)
			buff.text = "+%d balas" % ammo_gained if ammo_gained > 0 else "Munición llena"
		"rate":
			buff.text = "Cadencia +"
		"score":
			accent = Color(0.65, 0.80, 1.0)
			buff.text = "x2 puntos"
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

		button.pressed.connect(_on_shield_button_pressed)
		var fill := ProgressBar.new()
		fill.name = "ShieldFill"
		fill.show_percentage = false
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.max_value = TurrentController.SHIELD_DURATION
		fill.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		fill.add_theme_stylebox_override("fill", StyleBoxFlat.new())
		button.add_child(fill)
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var cut := ShieldCutEffect.new()
		cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.add_child(cut)
		cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var key_label := Label.new()
		key_label.text = button.text
		button.text = ""
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.add_theme_color_override("font_color", Color.WHITE)
		button.add_child(key_label)
		key_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_on_shield_changed(turret_controller.is_shield_up())

func _apply_shield_color() -> void:
	if not is_instance_valid(shield_buttons_container):
		return
	for child in shield_buttons_container.get_children():
		var button := child as Button
		if not button:
			continue
		for state in SHIELD_DARKENING:
			var template := button.get_theme_stylebox(state) as StyleBoxFlat
			if template:
				var style := template.duplicate() as StyleBoxFlat
				style.shadow_color = Color(shield_color, style.shadow_color.a)
				button.add_theme_stylebox_override(state, style)
		_tint_shield_warning(button, Color.WHITE, 0.0)
		var fill := button.get_node_or_null("ShieldFill") as ProgressBar
		if fill:
			var style := fill.get_theme_stylebox("fill") as StyleBoxFlat
			style.bg_color = Color(shield_color, 0.32)
			fill.get_child(0).tint = shield_color

func _tint_shield_warning(button: Button, warning_color: Color, weight: float) -> void:
	for state in SHIELD_DARKENING:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		if style:
			var base := shield_color.darkened(SHIELD_DARKENING[state])
			style.bg_color = Color(base.lerp(warning_color, weight), style.bg_color.a)

func _connect_turrets_buttons() -> void:
	for i in range(turret_buttons_container.get_child_count()):
		var button := turret_buttons_container.get_child(i) as Button

		if button == null:
			print("Turrets: fallo al conectar")
			continue

		button.pressed.connect(_on_turret_button_pressed.bind(i))

func _on_shield_button_pressed() -> void:
	turret_controller.activate_shield()

func _on_shield_changed(active: bool) -> void:
	if shield_buttons_container.get_child_count() > 0:
		var button := shield_buttons_container.get_child(0) as Button
		if button:
			button.disabled = active
			var fill := button.get_node("ShieldFill") as ProgressBar
			fill.visible = active
			if active:
				fill.value = TurrentController.SHIELD_DURATION
				fill.create_tween().tween_property(fill, "value", 0.0, TurrentController.SHIELD_DURATION)

func _on_turret_button_pressed(index: int) -> void:
	turret_controller.changed_to_turret(index)

func _on_beam_warning(lane: int, phase: int) -> void:

	if _blink_tween:
		_blink_tween.kill()
	if is_instance_valid(_warning_button):
		_tint_shield_warning(_warning_button, Color.WHITE, 0.0)
		_warning_button = null
	if phase == 2 or lane < 0:
			return
	if shield_buttons_container.get_child_count() == 0:
		return
	var b := shield_buttons_container.get_child(0) as Button

	if b == null:
		return
	_warning_button = b
	var color := Color(1.0, 0.68, 0.07) if phase == 0 else Color(1.0, 0.06, 0.12)
	var t := 0.25 if phase == 0 else 0.08
	var tint_warning := func(weight: float) -> void: _tint_shield_warning(b, color, weight)
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_method(tint_warning, 0.0, 0.85, t)
	_blink_tween.tween_method(tint_warning, 0.85, 0.0, t)
