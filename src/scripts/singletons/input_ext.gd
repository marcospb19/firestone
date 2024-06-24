extends Node


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta):
	# Mouse capture
	if Input.is_action_just_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("mouse_capture_exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Reset game
	if Input.is_action_just_pressed("reset"):
		self.get_tree().reload_current_scene()


func is_mouse_captured():
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
