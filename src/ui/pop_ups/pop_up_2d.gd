extends CanvasLayer
class_name PopUp2D

@onready var _popup: Control = $Popup
@onready var _title: Label = $Popup/Panel/Margin/Content/Title
@onready var _label: Label = $Popup/Panel/Margin/Content/Message
@onready var _details: VBoxContainer = $Popup/Panel/Margin/Content/Details

func _ready() -> void:
	_popup.hide()

func show_message(title: String, message: String, duration: float, detail: Control = null) -> void:
	for child in _details.get_children():
		child.queue_free()
		_details.remove_child(child)
	if detail:
		_details.add_child(detail)
	_title.text = title
	_title.visible = not title.strip_edges().is_empty()
	_label.text = message
	_popup.modulate.a = 0.0
	_popup.show()

	var transition := minf(0.18, duration * 0.5)
	var motion := create_tween()
	motion.tween_property(_popup, "modulate:a", 1.0, transition)
	motion.tween_interval(duration - transition * 2.0)
	motion.tween_property(_popup, "modulate:a", 0.0, transition)
	await motion.finished
	_popup.hide()

func model_row(models: Array[Node3D], labels: PackedStringArray) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	for i in models.size():
		var tile := VBoxContainer.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tile)

		var display := SubViewportContainer.new()
		display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		display.custom_minimum_size = Vector2(0, 108)
		display.stretch = true
		tile.add_child(display)
		
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		display.add_child(viewport)

		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.65
		camera.position = Vector3(0, 0, 2.6)
		camera.current = true
		viewport.add_child(camera)

		var key_light := DirectionalLight3D.new()
		key_light.rotation_degrees = Vector3(-32, -24, 0)
		viewport.add_child(key_light)
		viewport.add_child(models[i])

		var caption := Label.new()
		caption.text = labels[i]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 22)
		tile.add_child(caption)
	return row

func control_rows(hints: Dictionary[String, String]) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 14)
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.86, 0.83, 0.75)
	key_style.set_corner_radius_all(4)
	for key in hints:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 16)
		rows.add_child(row)

		var input := Label.new()
		input.text = key
		input.custom_minimum_size = Vector2(188, 44)
		input.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		input.add_theme_stylebox_override("normal", key_style)
		input.add_theme_color_override("font_color", Color(0.12, 0.12, 0.11))
		input.add_theme_font_size_override("font_size", 23)
		row.add_child(input)

		var caption := Label.new()
		caption.text = hints[key]
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 23)
		row.add_child(caption)
	return rows
