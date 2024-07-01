extends Node

# Have one main camera at a time to reference
var main_camera: Camera3D

# Sum delta over time
var elapsed_delta := 0.0


func set_main_camera(new_camera: Camera3D):
	main_camera = new_camera


func root() -> Window:
	return self.get_tree().root


# Apply a sin on the elapsed time
func time_sin(offset: float = 0.0, period_sec: float = 1.0) -> float:
	return sin((offset + elapsed_delta) * PI * 2 * period_sec)


func _process(delta: float):
	elapsed_delta += delta


# Helps scaling a value based on a custom curve with lower and upper bounds
#
# ```
#          x=range[1]
#              ↓
#              *---------  ← y=rate * (range[1] - range[0])
#             /
#            / ← y=rate * (clamped(value, range) - range[0])
#           /
# ---------* ← y=0
#          ↑  
#      x=range[0]
# ```
func custom_growth_curve(value: float, rate := 1.0, range_ := Vector2(0, 1)) -> float:
	assert(range_[1] > range_[0])
	var range_start := range_[0]
	var range_end := range_[1]
	
	var clamped := clampf(value, range_start, range_end)
	var range_position := clamped - range_start
	
	var increase_from_rate := range_position * rate
	return increase_from_rate


# BUG: low FPS makes the game run in slow motion
func set_low_fps_cap():
	Engine.max_fps = 45


func set_high_fps_cap():
	Engine.max_fps = 1000


func is_mouse_captured():
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
