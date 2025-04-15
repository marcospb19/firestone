extends Node

var main_camera: Camera3D
var elapsed_delta := 0.0

func set_main_camera(new_camera: Camera3D):
	main_camera = new_camera

func root() -> Window:
	return self.get_tree().root

func elapsed_sin(offset: float = 0.0, period_sec: float = 1.0) -> float:
	return sin((offset + elapsed_delta) * PI * 2 * period_sec)

func _process(delta: float):
	elapsed_delta += delta

func is_mouse_captured():
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
