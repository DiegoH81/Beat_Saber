extends WorldEnvironment

@export var sensibilidad: float = 6.0
@export_range(0.0, 1.0) var intensidad: float = 0.5
@export var suavizado: float = 15.0

var spectrum: AudioEffectSpectrumAnalyzerInstance
var sky_mat: ProceduralSkyMaterial
var base := {}

func _ready() -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	for i in AudioServer.get_bus_effect_count(bus_idx):
		var fx := AudioServer.get_bus_effect_instance(bus_idx, i)
		if fx is AudioEffectSpectrumAnalyzerInstance:
			spectrum = fx
			break

	sky_mat = environment.sky.sky_material as ProceduralSkyMaterial
	base = {
		"sky_top_color": sky_mat.sky_top_color,
		"sky_horizon_color": sky_mat.sky_horizon_color,
		"ground_horizon_color": sky_mat.ground_horizon_color,
		"ground_bottom_color": sky_mat.ground_bottom_color,
	}

func _process(delta: float) -> void:
	if not spectrum or not sky_mat:
		return

	var mag := spectrum.get_magnitude_for_frequency_range(20.0, 180.0).length()
	var energia := clampf(mag * sensibilidad, 0.0, 1.0)

	for prop in base:
		var pico: Color = base[prop].lightened(intensidad)
		var objetivo: Color = base[prop].lerp(pico, energia)
		sky_mat.set(prop, sky_mat.get(prop).lerp(objetivo, delta * suavizado))
