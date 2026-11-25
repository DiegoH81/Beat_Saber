extends Node3D

signal submitted(value: String)

@export var max_length: int = 39

@onready var address: Label3D = $Screen/Address
@onready var status: Label3D = $Screen/Status

var value: String = ""


func _ready() -> void:
	get_viewport().physics_object_picking = true
	set_value(value)


func set_value(new_value: String) -> void:
	value = new_value.left(max_length)
	address.text = value if not value.is_empty() else "0.0.0.0"
	address.pixel_size = minf(0.0018, 0.052 / maxf(1.0, value.length()))


func set_status(message: String) -> void:
	status.text = message


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				_on_key_pressed("Enter")
		KEY_BACKSPACE, KEY_DELETE:
			_on_key_pressed("Borrar")
		_:
			if event.unicode == 0:
				return
			var character := String.chr(event.unicode)
			if character not in "0123456789.":
				return
			_on_key_pressed(character)
	get_viewport().set_input_as_handled()


func _on_key_pressed(key: String) -> void:
	match key:
		"Enter":
			submitted.emit(value)
		"DEL":
			if not value.is_empty():
				set_value(value.left(-1))
		_:
			set_value(value + key)
