extends Node3D

const UDP_PORT := 5555

var udp := PacketPeerUDP.new()

@export var xr_camera_3d: XRCamera3D
@export var head: Node3D
@export var body: Node3D

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
var body_nodes := []  # todos los nodos que se desplazan junto con head

func _ready() -> void:
	process_priority = -1

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

	body_nodes = [
		left_hand, right_hand,
		left_wrist, right_wrist,
		left_elbow, right_elbow,
		left_shoulder, right_shoulder,
	]

	var err := udp.bind(UDP_PORT)
	if err != OK:
		print("Error al bindear el puerto %d: %s" % [UDP_PORT, err])
	else:
		print("Escuchando UDP en el puerto %d..." % UDP_PORT)


func _process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var packet := udp.get_packet()
		var text := packet.get_string_from_utf8()

		var json := JSON.new()
		var parse_err := json.parse(text)

		if parse_err != OK:
			print("Error parseando JSON: ", text)
			continue

		var data = json.get_data()
		_update_landmarks(data)
		_align_head_to_camera()


func _update_landmarks(data: Dictionary) -> void:
	if not data.has("landmarks"):
		return

	var landmarks: Dictionary = data["landmarks"]

	for index in landmarks.keys():
		if not landmark_nodes.has(index):
			continue

		var node: Node3D = landmark_nodes[index]
		if node == null:
			continue

		var values: Array = landmarks[index]
		# values = [x, y, z, visibility]
		var pos := Vector3(values[0], values[1], values[2])
		node.position = pos


func _align_head_to_camera() -> void:
	if xr_camera_3d == null or head == null:
		return

	# Diferencia entre la posición global de la cámara XR y la de head
	var offset := xr_camera_3d.global_position - head.global_position

	# Movemos head a la posición de la cámara
	head.global_position = xr_camera_3d.global_position

	# Aplicamos el mismo offset al resto del cuerpo para mantener la postura relativa
	for node in body_nodes:
		if node == null:
			continue
		node.global_position += offset
