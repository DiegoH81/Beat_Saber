extends Node3D

var thread: Thread
var mandos: Array = []


func _ready() -> void:
	thread = Thread.new()
	thread.start(_conectar_en_segundo_plano)


func _conectar_en_segundo_plano() -> void:
	GDWiimoteServer.set_max_wiimotes(2)
	GDWiimoteServer.initialize_connection(true)
	call_deferred("_on_conectado")


func _on_conectado() -> void:
	if thread and thread.is_started():
		thread.wait_to_finish()
	mandos = GDWiimoteServer.finalize_connection()

	var hijos := [$Sword1, $Sword2]

	for i in mini(hijos.size(), mandos.size()):
		hijos[i].asignar_wiimote(mandos[i], i)


func _exit_tree() -> void:
	if thread and thread.is_started():
		thread.wait_to_finish()
