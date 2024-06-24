extends Node

# Track the current camera to ensure that there is only one at a time
var current_camera: Camera3D

# Sum delta over time
var elapsed_delta := 0.0

func set_current_camera(id: Camera3D):
	assert(
		current_camera == null,
		"node %s tried setting current_camera but it wasn't null" % id,
	)
	current_camera = id


func clear_current_camera(id: Node):
	assert(
		current_camera == id,
		"node %s is exiting as camera, but it wasn't the camera" % id,
	)
	current_camera = null


func root() -> Window:
	return self.get_tree().root


# Apply a sin on the elapsed time
func time_sin(offset: float = 0.0, period_sec: float = 1.0) -> float:
	return sin((offset + elapsed_delta) * PI * 2 * period_sec)


func normalize(value: float, min: float, max: float) -> float:
	return (value - min) / (max - min)


func clamp_and_normalize(value: float, min: float, max: float) -> float:
	value = clampf(value, min, max)
	return (value - min) / (max - min)


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
func custom_growth_curve(value: float, rate := 1.0, range := Vector2(0, 1)) -> float:
	assert(range[1] > range[0])
	var range_start := range[0]
	var range_end := range[1]
	
	var clamped := clampf(value, range_start, range_end)
	var range_position := clamped - range_start
	
	var increase_from_rate := range_position * rate
	return increase_from_rate
