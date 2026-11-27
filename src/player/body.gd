extends Node3D

const UDP_PORT := 49152
const FRAME_EDGE_RIGHT := 1
const FRAME_EDGE_LEFT := 2
const TRACKING_TIMEOUT_MS := 650
const WARNING_DELAY_MS := 200
const BODY_LOST_WARNING := "No se detecta tu cuerpo.\nPonte frente al Kinect."

var udp := PacketPeerUDP.new()

@export var xr_camera_3d: XRCamera3D
@export var head: Node3D
@export var body: Node3D
@export var tracking_warning: Label3D

@export_category("Left Side")
@export var left_hand: Node3D
@export var left_wrist: Node3D
@export var left_elbow: Node3D
@export var left_shoulder: Node3D

@export_category("Right Side")
@export var right_hand: Node3D
@export var right_wrist: Node3D
@export var right_elbow: Node3D
@export var right_shoulder: Node3D

var landmark_nodes := {}
var last_packet_time := 0
var latest_warning := ""
var pending_warning := ""
var pending_warning_since := 0


func _ready() -> void:
	if not is_multiplayer_authority():
		set_process(false)
		return

	process_priority = -1
	last_packet_time = Time.get_ticks_msec()

	landmark_nodes = {
		"0": left_hand,
		"1": right_hand,
		"2": left_wrist,
		"3": right_wrist,
		"4": left_elbow,
		"5": right_elbow,
		"6": left_shoulder,
		"7": right_shoulder,
		"8": head,
	}

	var err := udp.bind(UDP_PORT)
	if err != OK:
		print("Error al bindear el puerto %d: %s" % [UDP_PORT, err])
	else:
		print("Escuchando UDP en el puerto %d..." % UDP_PORT)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var latest_frame: Dictionary = {}
	while udp.get_available_packet_count() > 0:
		var data: Variant = JSON.parse_string(udp.get_packet().get_string_from_utf8())
		if data is Dictionary and data.get("landmarks") is Dictionary:
			latest_frame = data

	if not latest_frame.is_empty():
		last_packet_time = now
		var landmarks: Dictionary = latest_frame["landmarks"]
		latest_warning = _get_tracking_warning(latest_frame, landmarks)
		_update_landmarks(landmarks)

	var warning := latest_warning
	if now - last_packet_time >= TRACKING_TIMEOUT_MS:
		warning = BODY_LOST_WARNING
	_show_tracking_warning(warning, now)


func _get_tracking_warning(frame: Dictionary, landmarks: Dictionary) -> String:
	if not frame.get("body_tracked", not landmarks.is_empty()):
		return BODY_LOST_WARNING

	# Los bordes se nombran desde Kinect. El jugador mira hacia el sensor.
	var edges := int(frame.get("clipped_edges", 0))
	match edges & (FRAME_EDGE_LEFT | FRAME_EDGE_RIGHT):
		FRAME_EDGE_LEFT:
			return "Muévete hacia tu izquierda."
		FRAME_EDGE_RIGHT:
			return "Muévete hacia tu derecha."

	if edges != 0:
		return "Colócate donde Kinect pueda\nver todo tu cuerpo."

	for index in landmark_nodes:
		var values: Array = landmarks.get(index, [])
		if values.size() < 4 or values[3] < 1.0:
			return "Kinect no ve todo tu cuerpo.\nCentra tu posición."
	return ""


func _show_tracking_warning(warning: String, now: int) -> void:
	if tracking_warning == null:
		return
	if warning != pending_warning:
		pending_warning = warning
		pending_warning_since = now
	if now - pending_warning_since >= WARNING_DELAY_MS and tracking_warning.text != warning:
		tracking_warning.text = warning
		tracking_warning.visible = not warning.is_empty()


func _update_landmarks(landmarks: Dictionary) -> void:
	var offset := Vector3.ZERO
	if xr_camera_3d != null and head != null:
		var head_values: Array = landmarks.get("8", [])
		if head_values.size() < 3:
			return
		head.position = Vector3(head_values[0], head_values[1], head_values[2])
		offset = xr_camera_3d.global_position - head.global_position

	for index in landmarks:
		var node: Node3D = landmark_nodes.get(index)
		if node == null:
			continue
		var values: Array = landmarks[index]
		if values.size() < 3:
			continue
		node.position = Vector3(values[0], values[1], values[2])
		node.global_position += offset
