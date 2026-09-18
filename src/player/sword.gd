extends Node3D

var sensibilidad := 0.5
var suavizado := 0.8

var wiimote: GDWiimote
var device_id := -1
var pos_base: Vector3
var accel_filtrado := Vector3.ZERO
var boto_acti: Dictionary = {}


func _ready() -> void:
	pos_base = position


func asignar_wiimote(w: GDWiimote, idx: int) -> void:
	wiimote = w
	device_id = idx
	w.set_motion_sensing(true)
	w.set_motion_plus(true)
	w.set_motion_processing(true)
	w.set_accel_threshold(2)

	w.reset_gyro_calibration()
	print("Espada ", name, " mando ", idx)


func _process(_delta: float) -> void:
	if wiimote == null:
		return

	var accel_crudo: Vector3 = wiimote.get_processed_accel()
	accel_filtrado = accel_filtrado.lerp(accel_crudo, suavizado)

	var x0 := accel_filtrado.x
	var y0 := accel_filtrado.z
	var z0 := accel_filtrado.y

	if accel_filtrado.length() < 0.1:
		x0 = 0.0
		y0 = 0.0
		z0 = 0.0

	position.x = pos_base.x + x0 * sensibilidad
	position.y = pos_base.y + y0 * sensibilidad
	position.z = pos_base.z + z0 * sensibilidad


func _input(event):
	if not (event is InputEventJoypadButton):
		return
	if event.device != device_id:
		return

	var key := str(event.device) + "_" + str(event.button_index)
	var presionado: bool = boto_acti.get(key, false)

	if event.pressed and not presionado:
		boto_acti[key] = true
		print("Wiimote ", event.device)
		match event.button_index:
			JOY_BUTTON_A: print(" A")
			JOY_BUTTON_B: print("  B")
			JOY_BUTTON_BACK: print(" (-)")
			JOY_BUTTON_GUIDE: print(" Home ")
			JOY_BUTTON_START: print(" (+)")
			JOY_BUTTON_DPAD_UP: print(" Up")
			JOY_BUTTON_DPAD_DOWN: print(" Down")
			JOY_BUTTON_DPAD_LEFT: print(" Left")
			JOY_BUTTON_DPAD_RIGHT: print(" Right")
	elif not event.pressed:
		boto_acti[key] = false
