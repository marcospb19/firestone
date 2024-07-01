extends Node

const AUDIO_PLAYER_COUNT := 32
var audio_players: Array[AudioStreamPlayer] = []
var next_player_index := 0


func _ready():
	for i in AUDIO_PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		audio_players.append(player)
		self.add_child(player)


func play_at_one_of(paths: Array[String], volume_modifier := 0):
	var path: String = paths.pick_random()
	assert(path != null)
	play_at(path, volume_modifier)


func play_at(path: String, volume_modifier := 0):
	var sound: AudioStream = load("res://assets/sounds/" + path)
	play(sound, volume_modifier)


func play(sound: AudioStream, volume_modifier := 0):
	var player: AudioStreamPlayer = audio_players[next_player_index]
	player.stream = sound
	player.volume_db = -18 + volume_modifier
	player.pitch_scale = randf_range(0.85, 1.15)
	player.play()
	next_player_index = wrapi(next_player_index + 1, 0, AUDIO_PLAYER_COUNT)
