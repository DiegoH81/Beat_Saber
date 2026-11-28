extends Node3D
class_name AmmoHologram

const COLOR_OK := Color(0.30, 0.92, 1.0)
const COLOR_LOW := Color(1.0, 0.72, 0.16)
const COLOR_EMPTY := Color(1.0, 0.18, 0.24)
const SEGMENTS := 16
const LOW_RATIO := 0.25
const PANEL_SIZE := Vector2(0.46, 0.24)
const SEGMENT_GAP := 0.004
const HOLOGRAM_SCALE := 1.3
const COUNT_Y := 0.035
const COUNT_Y_SOLO := 0.005

var _root: Node3D

var _panel: MeshInstance3D
var _edge: MeshInstance3D
var _count: Label3D
var _caption: Label3D
var _segments: Array[MeshInstance3D] = []
var _blink: Tween
var _reload_tween: Tween
var _pulse_tween: Tween
var _reloading := false
var _ammo := 0
var _max_ammo := 1


func _ready() -> void:
	_build()


func set_ammo(current: int, max_ammo: int) -> void:
	_ammo = current
	_max_ammo = maxi(max_ammo, 1)
	if _reloading:
		_end_reload()
	_refresh()
	if current > 0:
		_pulse()


func start_reload(duration: float) -> void:
	_reloading = true
	_stop_blink()
	_set_color(COLOR_OK)
	_count.text = "RECARGANDO"
	_count.font_size = 58
	_count.position.y = COUNT_Y
	_caption.text = "· · ·"
	if _reload_tween:
		_reload_tween.kill()
	_reload_tween = create_tween()
	_reload_tween.tween_method(_fill_segments, 0.0, 1.0, maxf(duration, 0.05))
	_start_blink(0.35, 0.55)


func _end_reload() -> void:
	_reloading = false
	if _reload_tween:
		_reload_tween.kill()


func _refresh() -> void:
	var ratio := float(_ammo) / float(_max_ammo)
	_fill_segments(ratio)
	_stop_blink()
	if _ammo <= 0:
		_set_color(COLOR_EMPTY)
		_count.text = "RECARGA [R]"
		_count.font_size = 58
		_count.position.y = COUNT_Y
		_caption.text = "SIN MUNICIÓN"
		_start_blink(0.22, 0.25)
		return

	_set_color(COLOR_LOW if ratio <= LOW_RATIO else COLOR_OK)
	_count.text = "%d/%d" % [_ammo, _max_ammo]
	_count.font_size = 120
	_count.position.y = COUNT_Y_SOLO
	_caption.text = ""


func _fill_segments(ratio: float) -> void:
	var lit := ceili(clampf(ratio, 0.0, 1.0) * SEGMENTS)
	for i in _segments.size():
		var material := _segments[i].material_override as StandardMaterial3D
		material.albedo_color.a = 0.95 if i < lit else 0.12


func _set_color(color: Color) -> void:
	_count.modulate = color
	_caption.modulate = Color(color, 0.85)
	var panel_material := _panel.material_override as StandardMaterial3D
	panel_material.albedo_color = Color(color.darkened(0.75), 0.38)
	var edge_material := _edge.material_override as StandardMaterial3D
	edge_material.albedo_color = Color(color, 0.9)
	for segment in _segments:
		var material := segment.material_override as StandardMaterial3D
		material.albedo_color = Color(color, material.albedo_color.a)


func _start_blink(period: float, low_alpha: float) -> void:
	_blink = create_tween().set_loops()
	_blink.tween_property(_count, "transparency", 1.0 - low_alpha, period)
	_blink.tween_property(_count, "transparency", 0.0, period)


func _stop_blink() -> void:
	if _blink:
		_blink.kill()
	_count.transparency = 0.0


func _pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_count.scale = Vector3.ONE * 1.08
	_pulse_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_count, "scale", Vector3.ONE, 0.08)


# Construcción ---------------------------------------------------------------

func _build() -> void:
	_root = Node3D.new()
	_root.scale = Vector3.ONE * HOLOGRAM_SCALE
	add_child(_root)
	_panel = _quad(PANEL_SIZE, Vector3.ZERO, -1)
	var glass := _panel.material_override as StandardMaterial3D
	glass.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_edge = _quad(Vector2(PANEL_SIZE.x, 0.006), Vector3(0, PANEL_SIZE.y * 0.5, 0.001), 0)
	var bottom_edge := _quad(Vector2(PANEL_SIZE.x * 0.35, 0.004), Vector3(-PANEL_SIZE.x * 0.325, -PANEL_SIZE.y * 0.5, 0.001), 0)
	bottom_edge.material_override = _edge.material_override

	_count = _label(120, Vector3(0, COUNT_Y_SOLO, 0.002))
	_caption = _label(34, Vector3(0, -0.045, 0.002))

	var bar_width := PANEL_SIZE.x * 0.86
	var segment_width := (bar_width - SEGMENT_GAP * (SEGMENTS - 1)) / SEGMENTS
	var start_x := -bar_width * 0.5 + segment_width * 0.5
	for i in SEGMENTS:
		var x := start_x + i * (segment_width + SEGMENT_GAP)
		_segments.append(_quad(Vector2(segment_width, 0.018), Vector3(x, -0.085, 0.002), 1))
	_refresh()


func _quad(size: Vector2, pos: Vector3, priority: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.no_depth_test = true
	material.disable_fog = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = priority
	material.albedo_color = Color(COLOR_OK, 0.9)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = pos
	_root.add_child(mesh)
	return mesh


func _label(size: int, pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.font_size = size
	label.pixel_size = 0.0009
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.no_depth_test = true
	label.fixed_size = false
	label.render_priority = 2
	label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = pos
	_root.add_child(label)
	return label
