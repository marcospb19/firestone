extends Node

# Track the current camera to ensure that there is only one at a time
var current_camera: Camera3D


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
