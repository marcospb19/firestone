extends Camera3D


func _ready():
	Utils.set_current_camera(self)


func _exit_tree():
	Utils.clear_current_camera(self)
