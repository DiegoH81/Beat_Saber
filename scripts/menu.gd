extends Control

@export_dir var music_output_dir: String = "res://levels_data/music"
@export_dir var info_output_dir: String = "res://levels_data/info"

@onready var input_path: LineEdit = $VBoxContainer/InputPath
@onready var check_is_url: CheckBox = $VBoxContainer/CheckIsUrl
@onready var btn_process: Button = $VBoxContainer/BtnProcess
@onready var lbl_status: Label = $VBoxContainer/LblStatus
@onready var txt_output: TextEdit = $VBoxContainer/TxtOutput

var worker_thread: Thread

func _ready() -> void:
	btn_process.pressed.connect(_on_btn_process_pressed)

func _on_btn_process_pressed() -> void:
	var source_path = input_path.text.strip_edges()
	if source_path == "":
		lbl_status.text = "Error, invalid location"
		return
	
	btn_process.disabled = true
	lbl_status.text = "Processing ..."
	txt_output.text = ""
	
	worker_thread = Thread.new()
	worker_thread.start(_thread_process_song.bind(source_path, check_is_url.button_pressed))

func _thread_process_song(source_path: String, is_url: bool) -> void:
	var global_python_script = ProjectSettings.globalize_path("res://external/python/MusicManager.py")
	var global_music_dir = ProjectSettings.globalize_path(music_output_dir)
	var global_info_dir = ProjectSettings.globalize_path(info_output_dir)
	
	DirAccess.make_dir_recursive_absolute(global_music_dir)
	DirAccess.make_dir_recursive_absolute(global_info_dir)

	var args = PackedStringArray([
		global_python_script,
		global_music_dir,
		global_info_dir,
		source_path,
		"true" if is_url else "false"
	])
	
	var output = []
	
	var exit_code = OS.execute("python", args, output, true)
	
	call_deferred("_on_process_finished", exit_code, source_path, output)

func _on_process_finished(exit_code: int, source_path: String, output: Array) -> void:
	if worker_thread.is_started():
		worker_thread.wait_to_finish()
		
	btn_process.disabled = false
	
	if exit_code == 0:
		lbl_status.text = "Processed Song!"
		read_and_display_txt(source_path)
	else:
		lbl_status.text = "Error processing song!"
		if output.size() > 0:
			txt_output.text = output[0]

func read_and_display_txt(source_path: String) -> void:
	var song_name = source_path.get_file().get_basename()
	var txt_path = info_output_dir.path_join(song_name + ".txt")
	
	if FileAccess.file_exists(txt_path):
		var file = FileAccess.open(txt_path, FileAccess.READ)
		txt_output.text = file.get_as_text()
		file.close()
	else:
		lbl_status.text = "Couldn't find .txt file"
