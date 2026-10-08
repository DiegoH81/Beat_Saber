@tool
extends Node3D

signal popup_finished

@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var texto_mesh: MeshInstance3D = $Texto
@onready var button: Area3D = $Button

@export_group("Content")
@export_multiline var texto: String = "Text":
	set(value):
		texto = value
		_update_popup()

@export var imagen_textura: Texture2D:
	set(value):
		imagen_textura = value
		_update_popup()

@export var escala_imagen: Vector3 = Vector3.ONE:
	set(value):
		escala_imagen = value
		_update_popup()
		
func _ready() -> void:
	#process_mode = Node.PROCESS_MODE_ALWAYS
	_update_popup()
	
	if not Engine.is_editor_hint():
		if button and button.has_signal("pressed"):
			if not button.pressed.is_connected(_on_button_pressed):
				button.pressed.connect(_on_button_pressed)


func _update_popup() -> void:
	if not is_node_ready():
		await ready

	if texto_mesh and texto_mesh.mesh is TextMesh:
		texto_mesh.mesh.text = texto
		
	if sprite_3d:
		sprite_3d.texture = imagen_textura
		sprite_3d.scale = escala_imagen


func _on_button_pressed() -> void:
	cerrar_popup()


func cerrar_popup() -> void:
	if Engine.is_editor_hint():
		return
		
	emit_signal("popup_finished")
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	
	queue_free()
