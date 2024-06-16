extends Node

const AUDIO_PLAYER_COUNT := 16
var players := []
var next_player_index := 0


func _ready():
	for i in AUDIO_PLAYER_COUNT:
		var player = AudioStreamPlayer.new()
		player.volume_db = -25
		players.append(player)
		self.add_child(player)


## path: String | Array[String]
func play_at(path: Variant):
	if path is Array:
		path = path.pick_random()
	if not path is String:
		push_error("wrong type for `path`: ", type_string(typeof(path)))
	
	var sound = load("res://assets/sounds/" + path)
	play(sound)


func play(sound: Resource):
	var player = players[next_player_index]
	player.stream = sound
	player.pitch_scale = randf_range(0.9, 1.1)
	player.play()
