import json
import librosa
import numpy as np
import os

def obtener_intensidad_audio(y, sr, tiempo_seg, ventana_ms=100):
    """Calcula la intensidad/energía (RMS) del audio en un instante específico."""
    sample_inicio = int(max(0, (tiempo_seg - (ventana_ms / 2000.0)) * sr))
    sample_fin = int(min(len(y), (tiempo_seg + (ventana_ms / 2000.0)) * sr))
    
    segmento = y[sample_inicio:sample_fin]
    if len(segmento) == 0:
        return 0.0
    
    # Calcular Valor Eficaz / RMS
    rms = np.sqrt(np.mean(segmento**2))
    # Normalizar en un rango aproximado de 0.0 a 1.0 (clipping preventivo)
    intensidad = min(1.0, float(rms * 3.0)) 
    return round(intensidad, 3)

def parsear_nivel_con_audio(info_path: str, diff_path: str, audio_path: str, output_path: str = "resultado.json"):
    # 1. Cargar y analizar el archivo de sonido (.ogg / .egg)
    print(f"Cargando archivo de audio: {audio_path}...")
    y, sr = librosa.load(audio_path, sr=None)
    duracion_real_audio = round(librosa.get_duration(y=y, sr=sr), 2)

    # 2. Leer Info.dat
    with open(info_path, 'r', encoding='utf-8') as f:
        info_data = json.load(f)
    
    nombre = info_data.get("_songName", "Desconocido")
    sub_nombre = info_data.get("_songSubName", "")
    artista = info_data.get("_songAuthorName", "Desconocido")
    mapper = info_data.get("_levelAuthorName", "Desconocido")
    bpm = float(info_data.get("_beatsPerMinute", 120.0))

    DIRECCIONES_CORTE = {
        0: "Arriba", 1: "Abajo", 2: "Izquierda", 3: "Derecha",
        4: "Diagonal_Arriba_Izquierda", 5: "Diagonal_Arriba_Derecha",
        6: "Diagonal_Abajo_Izquierda", 7: "Diagonal_Abajo_Derecha",
        8: "Cualquiera"
    }

    # 3. Leer archivo de dificultad
    with open(diff_path, 'r', encoding='utf-8') as f:
        diff_data = json.load(f)

    version = str(diff_data.get("version") or diff_data.get("_version", "2.0.0"))
    notas_procesadas = []

    if version.startswith("3"):
        raw_notes = diff_data.get("colorNotes", [])
        for n in raw_notes:
            beat = n.get("b", 0.0)
            tiempo_seg = round((beat * 60.0) / bpm, 3)
            x, y_grid = n.get("x", 0), n.get("y", 0)
            carril_idx = (2 - y_grid) * 4 + x

            intensidad = obtener_intensidad_audio(y, sr, tiempo_seg)

            notas_procesadas.append({
                "time": tiempo_seg,
                "lane": carril_idx,
                "direccion_corte": DIRECCIONES_CORTE.get(n.get("d", 8), "Desconocido"),
                "intensity": intensidad
            })
    else:
        raw_notes = diff_data.get("_notes", [])
        for n in raw_notes:
            if n.get("_type") in (0, 1):
                beat = n.get("_time", 0.0)
                tiempo_seg = round((beat * 60.0) / bpm, 3)
                x, y_grid = n.get("_lineIndex", 0), n.get("_lineLayer", 0)
                carril_idx = (2 - y_grid) * 4 + x

                intensidad = obtener_intensidad_audio(y, sr, tiempo_seg)

                notas_procesadas.append({
                    "time": tiempo_seg,
                    "lane": carril_idx,
                    "direccion_corte": DIRECCIONES_CORTE.get(n.get("_cutDirection", 8), "Desconocido"),
                    "intensity": intensidad
                })

    notas_procesadas.sort(key=lambda x: x["time"])

    json_salida = {
        "NAME": nombre,
        "ARTIST": artista,
        "DURATION": duracion_real_audio,
        "BPM": bpm,
        "NOTES": notas_procesadas
    }

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(json_salida, f, indent=4, ensure_ascii=False)

    print(f"Completado exitosamente. Salida guardada en: {output_path}")

if __name__ == "__main__":
    ruta_script = os.path.dirname(os.path.abspath(__file__))
    print(ruta_script)
    parsear_nivel_con_audio(
        info_path="info.dat", 
        diff_path="EasyStandard.dat", 
        audio_path="song.egg",
        output_path="level.json"
    )