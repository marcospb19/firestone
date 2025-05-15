class_name Hotbar

var elements: Array[VoxelWorld.BlockKind] = [
	VoxelWorld.BlockKind.DIRT,
	VoxelWorld.BlockKind.STONE,
	VoxelWorld.BlockKind.GATE_AND,
]

func access(index: int):
	if index >= elements.size():
		return null
	return elements[index]
