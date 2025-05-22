class_name Hotbar

const HOTBAR_ELEMENTS: Array[VoxelWorld.BlockKind] = [
	VoxelWorld.BlockKind.DIRT,
	VoxelWorld.BlockKind.STONE,
	VoxelWorld.BlockKind.NOT,
	VoxelWorld.BlockKind.AND,
	VoxelWorld.BlockKind.OR,
]

var __selected_index := 0

func get_selected():
	if __selected_index >= HOTBAR_ELEMENTS.size():
		return null
	return HOTBAR_ELEMENTS[__selected_index]

func get_selected_index():
	return __selected_index

## Returns whether the event was treated or ignored
func handle_input_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			__selected_index = (__selected_index + 1) % 9
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			__selected_index = (__selected_index + 8) % 9
			return true
	elif event is InputEventKey:
		var number = Utils2.parse_hotbar_number(event)
		if number != null:
			__selected_index = number - 1
			return true
	return false
