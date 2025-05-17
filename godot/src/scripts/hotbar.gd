class_name Hotbar

var elements: Array[VoxelWorld.FaceKind] = [
	VoxelWorld.FaceKind.DIRT,
	VoxelWorld.FaceKind.STONE,
	VoxelWorld.FaceKind.AND_BLANK,
	VoxelWorld.FaceKind.NOT_BLANK,
]

func access(index: int):
	if index >= elements.size():
		return null
	return elements[index]
