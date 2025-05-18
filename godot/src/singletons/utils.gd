extends Node

const BLOCK_WIDTH := 1.00
const EPSILON := 0.00001
const MILLI := 0.001

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

# Swaps the window with a corresponding window at the end
func swap_remove_window(arr, window_index: int, window_size: int):
	var start = window_index * window_size
	var end = (window_index + 1) * window_size

	# The end window overlaps with the remove window
	var window_overlaps = end == arr.size()
	if window_overlaps:
		for _i in range(start, end):
			arr.remove_at(arr.size() - 1)
		return

	for i in window_size:
		arr[end - i - 1] = arr[-i - 1]
	arr.resize(arr.size() - window_size)
