extends Node3D

@export var color_activo: Color = Color.GREEN
@export var color_inactivo: Color = Color.DARK_GRAY

var segmentos: Array[MeshInstance3D] = []

func _ready() -> void:
	_obtener_segmentos()

func _obtener_segmentos() -> void:
	if segmentos.is_empty():
		for child in get_children():
			if child is MeshInstance3D:
				var mat = StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				child.material_override = mat
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				segmentos.append(child)

func set_nivel(valor: int) -> void:
	_obtener_segmentos()
	
	var activos = clampi(valor, 0, segmentos.size())
	
	for i in range(segmentos.size()):
		var mat = segmentos[i].material_override as StandardMaterial3D
		if mat:
			if i < activos:
				mat.albedo_color = color_activo
			else:
				mat.albedo_color = color_inactivo
