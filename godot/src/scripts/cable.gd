class_name Cable extends CSGBox3D

var start: Vector3
var end: Vector3

var is_on := false:
	set(value):
		is_on = value
		self.material.albedo_color = Color.CYAN if is_on else Color.DARK_SLATE_GRAY

func _init(start_: Vector3, end_: Vector3):
	self.start = start_
	self.end = end_

func _enter_tree():
	self.look_at(start - end)
	self.position = (start + end) / 2.0

	var distance = (start - end).length() + 0.1
	self.size = Vector3(0.1, 0.1, distance)

	self.material = StandardMaterial3D.new()
	self.material.albedo_color = Color.YELLOW
