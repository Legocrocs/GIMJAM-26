extends AudioStreamPlayer2D
@onready var bgm_player = $BGMPlayer

func play_new_track(track_path: String):
	var new_track = load(track_path)
	if bgm_player.stream != new_track:
		bgm_player.stream = new_track
		bgm_player.play()

func lower_volume():
	bgm_player.volume_db = -10
