class_name Hotbar

const HOTBAR_ELEMENTS: Array[VoxelWorld.FaceKind] = [
	VoxelWorld.FaceKind.DIRT,
	VoxelWorld.FaceKind.STONE,
	VoxelWorld.FaceKind.NOT_BLANK,
	VoxelWorld.FaceKind.AND_BLANK,
	VoxelWorld.FaceKind.OR_BLANK,
]

var __selected_index := 0

func get_selected():
	if __selected_index >= HOTBAR_ELEMENTS.size():
		return null
	return HOTBAR_ELEMENTS[__selected_index]

func get_selected_index():
	return __selected_index

func handle_input_event(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			__selected_index = (__selected_index + 1) % 9
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			__selected_index = (__selected_index + 8) % 9
	elif event is InputEventKey:
		var number = Utils2.parse_hotbar_number(event)
		if number != null:
			__selected_index = number - 1
