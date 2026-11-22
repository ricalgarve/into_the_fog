extends Node

const AUDIO_BASE := "res://assets/audios/"

var bgm_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var _last_voice_path: String = ""

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.volume_db = -12.0
	add_child(bgm_player)

	voice_player = AudioStreamPlayer.new()
	voice_player.name = "VoicePlayer"
	voice_player.volume_db = 2.0
	add_child(voice_player)

func start_match_audio(player_choice: String) -> void:
	_play_bgm()
	var start_folder := AUDIO_BASE + ("audio inicio bolsonaro" if player_choice == "bolsonaro" else "audio inicio lula")
	_play_random_from_folder(start_folder)

func play_upscore_audio(player_choice: String) -> void:
	var folder := AUDIO_BASE + ("audios upscore bolsonaro" if player_choice == "bolsonaro" else "audios upscore lula")
	_play_random_from_folder(folder)

func _play_bgm() -> void:
	var files := _list_audio_files(AUDIO_BASE + "musica fundo")
	if files.is_empty():
		return
	var stream := _load_audio_stream(files[0])
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	bgm_player.stream = stream
	bgm_player.play()

func _play_random_from_folder(folder_path: String) -> void:
	var files := _list_audio_files(folder_path)
	if files.is_empty():
		return

	var chosen := files[randi() % files.size()]
	if files.size() > 1 and chosen == _last_voice_path:
		chosen = files[(files.find(chosen) + 1) % files.size()]
	_last_voice_path = chosen

	var stream := _load_audio_stream(chosen)
	if stream != null:
		voice_player.stream = stream
		voice_player.play()

func _list_audio_files(folder_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_warning("[AudioManager] Pasta não encontrada: " + folder_path)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			if lower.ends_with(".mp3") or lower.ends_with(".ogg") or lower.ends_with(".wav"):
				result.append(folder_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func _load_audio_stream(res_path: String) -> AudioStream:
	if ResourceLoader.exists(res_path):
		var loaded := load(res_path) as AudioStream
		if loaded != null:
			return loaded
	var abs_path := ProjectSettings.globalize_path(res_path)
	if res_path.to_lower().ends_with(".mp3"):
		return AudioStreamMP3.load_from_file(abs_path)
	return null
