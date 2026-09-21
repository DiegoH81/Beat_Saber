extends Node3D

const UDP_PORT := 5555

var udp := PacketPeerUDP.new()

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

func _ready() -> void:
	landmark_nodes = {
		"0": left_hand,
		"1": right_hand,
		"2": left_wrist,
		"3": right_wrist,
		"4": left_elbow,
		"5": right_elbow,
		"6": left_shoulder,
		"7": right_shoulder,
	}

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
