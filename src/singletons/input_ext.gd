extends Node


func _process(event):
	# Mouse capture
	if Input.is_action_just_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("mouse_capture_exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_mouse_captured():
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
