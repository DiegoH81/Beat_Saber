extends Node3D

## Tutorial del P2: todo va por tiempo de la canción, nada espera al jugador.
## El Generator (tutorial_mode) pone los amarillos y los rayos en segundos fijos
## y aquí solo se muestra el texto que toca en cada tramo.

const PRACTICE_POWERUP_DELAY := 1.0
const PRACTICE_POWERUP_FALL := 7.0
const KEY_COLOR := "#c9a6ff"
const FADE_TIME := 0.25
const GLOW_COLOR := Color(0.72, 0.38, 1.0)
## El aviso de PELIGRO dura 2.2 s, así que la torreta cae a los ~50 s.
const FIRST_STATION_ATTACK := 48.0

## {TECLA} se dibuja como tecla resaltada.
const STEPS := [
	{"from": 1.0, "to": 8.5, "title": "POTENCIADORES",
		"text": "Dispárales para activarlos: balas, cadencia o x2 puntos para el P1"},
	{"from": 9.0, "to": 13.5, "title": "BALAS",
		"text": "Si te quedas sin balas, pulsa {R} para recargar"},
	{"from": 14.5, "to": 26.0, "title": "CUBOS AMARILLOS",
		"text": "Destrúyelos antes de que lleguen: el P1 no puede cortarlos"},
	{"from": 28.5, "to": 36.0, "title": "RAYO",
		"text": "Cuando el rayo se cargue, pulsa {ESPACIO} para activar el escudo"},
]

@onready var _level := get_parent() as Level

var _coach: Control
var _title: Label
var _text: RichTextLabel
var _fade: Tween
var _step := -1


func _ready() -> void:
	_level.song_start_sequence = _start_song
	if _level.generator:
		_level.generator.tutorial_mode = true
	ScoreManager.ignore_p2_errors = true
	set_process(false)


func _exit_tree() -> void:
	ScoreManager.ignore_p2_errors = false


func _start_song(special_indices: PackedInt32Array) -> void:
	if multiplayer.get_peers().is_empty():
		_level.start_gameplay(special_indices)
		return

	_level.start_gameplay(special_indices, -1.0, PRACTICE_POWERUP_FALL, PRACTICE_POWERUP_DELAY)
	if not multiplayer.is_server():
		if _level.turret_controller:
			_level.turret_controller.delay_first_station_attack(FIRST_STATION_ATTACK)
		_build_coach()
		set_process(true)


func _process(_delta: float) -> void:
	var t := _level.generator.duration if _level.generator else 0.0
	var current := -1
	for i in STEPS.size():
		if t >= STEPS[i].from and t < STEPS[i].to:
			current = i
			break
	if current != _step:
		_step = current
		_show_step(current)
	if t > STEPS[-1].to:
		set_process(false)


func _show_step(index: int) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if index < 0:
		_fade.tween_property(_coach, "modulate:a", 0.0, FADE_TIME)
		return
	_title.text = "TUTORIAL  —  %s" % STEPS[index].title
	_text.text = "[center]%s[/center]" % _format_keys(STEPS[index].text)
	_coach.modulate.a = 0.0
	_coach.position.y = _coach_rest_y() + 12.0
	_fade.tween_property(_coach, "modulate:a", 1.0, FADE_TIME)
	_fade.parallel().tween_property(_coach, "position:y", _coach_rest_y(), FADE_TIME)


func _format_keys(text: String) -> String:
	var regex := RegEx.create_from_string("\\{([^}]+)\\}")
	return regex.sub(text, "[color=%s][b][lb]$1[rb][/b][/color]" % KEY_COLOR, true)


func _coach_rest_y() -> float:
	return get_viewport().get_visible_rect().size.y - 118.0 - _coach.size.y


func _build_coach() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_coach = PanelContainer.new()
	_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.02, 0.10, 0.82)
	style.border_color = GLOW_COLOR
	style.set_border_width_all(2)
	style.shadow_color = Color(GLOW_COLOR, 0.55)
	style.shadow_size = 22
	style.set_corner_radius_all(8)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_coach.add_theme_stylebox_override("panel", style)
	layer.add_child(_coach)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	_coach.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(0.79, 0.65, 1.0, 0.85))
	box.add_child(_title)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 30)
	_text.add_theme_font_size_override("bold_font_size", 30)
	_text.add_theme_color_override("default_color", Color(0.96, 0.95, 0.98))
	box.add_child(_text)

	_coach.custom_minimum_size.x = 900.0
	_coach.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_coach.offset_left = -450.0
	_coach.offset_right = 450.0
	_coach.modulate.a = 0.0

	# Resplandor morado que respira en los bordes.
	var glow := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow.tween_method(_set_glow.bind(style), 0.0, 1.0, 1.1)
	glow.tween_method(_set_glow.bind(style), 1.0, 0.0, 1.1)


func _set_glow(amount: float, style: StyleBoxFlat) -> void:
	style.shadow_color = Color(GLOW_COLOR, lerpf(0.40, 0.85, amount))
	style.shadow_size = int(lerpf(16.0, 30.0, amount))
	style.border_color = GLOW_COLOR.lerp(Color.WHITE, amount * 0.35)
