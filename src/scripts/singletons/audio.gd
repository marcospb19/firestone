extends Node

const AUDIO_PLAYER_COUNT := 32
var audio_players: Array[AudioStreamPlayer] = []
var next_player_index := 0


func _ready():
	for i in AUDIO_PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		audio_players.append(player)
		self.add_child(player)


func play_at_one_of(paths: Array[String]):
	var path: String = paths.pick_random()
	assert(path != null)
	play_at(path)


func play_at(path: String):
	var sound: AudioStream = load("res://assets/sounds/" + path)
	play(sound)


func play(sound: AudioStream, volume_modifier := 0):
	var player: AudioStreamPlayer = audio_players[next_player_index]
	player.stream = sound
	player.volume_db = -25 + volume_modifier
	player.pitch_scale = randf_range(0.9, 1.1)
	player.play()
	next_player_index = wrapi(next_player_index + 1, 0, AUDIO_PLAYER_COUNT)
