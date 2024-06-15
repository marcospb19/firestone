extends Node

var num_players := 12
var bus := "master"

var available := []  # The available players.
var queue := []  # The queue of sounds to play.


func _ready():
	for i in num_players:
		var p = AudioStreamPlayer.new()
		self.add_child(p)
		available.append(p)
		p.volume_db = -30
		p.finished.connect(_on_stream_finished.bind(p))
		p.bus = bus

func _on_stream_finished(stream):
	available.append(stream)

func play(sounds):
	if sounds is String:
		queue.append("res://" + sounds)
	elif sounds is Array:
		var sound = sounds[randi() % sounds.size()]
		queue.append("res://" + sound)
	else:
		push_error('invalid sound path!')

func _process(_delta):
	if not queue.is_empty() and not available.is_empty():
		available[0].stream = load(queue.pop_front())
		available[0].play()
		available[0].pitch_scale = randf_range(0.9, 1.1)
		
		available.pop_front()
