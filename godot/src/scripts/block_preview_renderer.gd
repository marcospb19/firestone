extends SubViewport

@onready var camera: Camera3D = $Camera3D
@onready var own_voxel_world := $VoxelWorld

func setup_block_and_camera(block_kind: VoxelWorld.BlockKind):
	own_voxel_world.add_block(Vector3i.ZERO, block_kind)
	if VoxelWorld.is_block_gate(block_kind):
		var input_face = VoxelWorld.block_input_face(block_kind)
		own_voxel_world.update_face_uv(Vector3i.ZERO, VoxelWorld.Face.FRONT, input_face)

	camera.transform.origin = Vector3(2, 1.3, 2)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
