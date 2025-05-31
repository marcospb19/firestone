extends Node3D

const DIMENSIONS := Vector3i(16, 1, 16)
const BLOCK_SIZE := 1.0

@onready var player = $Player
@onready var player_initial_position = player.position
@onready var voxel_world: VoxelWorld = $VoxelWorld

func _ready():
	voxel_world.block_size = BLOCK_SIZE
	var random = FastNoiseLite.new()
	random.noise_type = FastNoiseLite.TYPE_SIMPLEX

	for x in DIMENSIONS.x:
		for y in DIMENSIONS.y:
			for z in DIMENSIONS.z:
				# const CUT_OFF := 0.0
				# if random.get_noise_3d(x, y, z) > CUT_OFF:
				var coordinate = Vector3i(x, y, z)
				coordinate -= DIMENSIONS / 2 # centralize
				coordinate.y -= 2.0
				add_block_at(coordinate, voxel_world.BlockKind.STONE)

func add_block_at_world_offset(pos: Vector3, block_kind: VoxelWorld.BlockKind, look_direction: Vector3):
	add_block_at(voxel_world.position_to_coordinate(pos), block_kind, look_direction)

func add_block_at(coordinate: Vector3i, block_kind: VoxelWorld.BlockKind, look_direction: Vector3 = Vector3.FORWARD):
	# Don't place a block if it collides with the player
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = BoxShape3D.new()
	params.shape.size = Vector3.ONE * 0.99 * voxel_world.block_size
	params.transform = Transform3D(Basis.IDENTITY, voxel_world.coordinate_to_position(coordinate))
	var collisions = self.get_world_3d().get_direct_space_state().intersect_shape(params, 2)
	for collision in collisions:
		if collision["rid"] == $Player.get_rid():
			return

	voxel_world.disable_updates = true
	voxel_world.add_block(coordinate, block_kind)

	if VoxelWorld.is_block_gate(block_kind):
		var input_face = VoxelWorld.look_direction_to_face(-look_direction)
		var output_face = VoxelWorld.look_direction_to_face(look_direction)
		voxel_world.update_face_uv(voxel_world.block_positions[-1], input_face, VoxelWorld.block_input_face(block_kind))
		voxel_world.update_face_uv(voxel_world.block_positions[-1], output_face, VoxelWorld.block_output_face(block_kind))
		voxel_world.blocks[Vector3i(voxel_world.block_positions[-1])].input_face = input_face
		voxel_world.blocks[Vector3i(voxel_world.block_positions[-1])].output_face = output_face
	voxel_world.disable_updates = false
	voxel_world.enqueue_mesh_update()

func remove_block_at_world_offset(pos: Vector3):
	voxel_world.remove_block(voxel_world.position_to_coordinate(pos))

func _on_voxel_world_updated() -> void:
	$StaticBody3D/CollisionShape3D.shape = voxel_world.mesh.create_trimesh_shape()

func _on_player_connect_faces(from: Vector3, _from_face: VoxelWorld.Face, to: Vector3, _to_face: VoxelWorld.Face):
	var from_coords = voxel_world.position_to_coordinate(from)
	var to_coords = voxel_world.position_to_coordinate(to)

	if from_coords == to_coords:
		printerr('cant connect block to itself')
		return

	var from_block = voxel_world.blocks[from_coords]
	var to_block = voxel_world.blocks[to_coords]
	if not VoxelWorld.is_block_gate(from_block.block_kind):
		printerr('first block is not valid gate, cancelling connection')
		return
	if not VoxelWorld.is_block_gate(to_block.block_kind):
		printerr('second block is not valid gate, cancelling connection')
		return

	var from_output_offset = VoxelWorld.FACE_NORMALS[from_block.output_face] * (0.5 + Cable.CABLE_WIDTH() / 2.0)
	var to_input_offset = VoxelWorld.FACE_NORMALS[to_block.input_face] * (0.5 + Cable.CABLE_WIDTH() / 2.0)

	var success = $CircuitSimulation.connect_blocks(from_coords, to_coords, from_block.block_kind == VoxelWorld.BlockKind.AND, to_block.block_kind == VoxelWorld.BlockKind.AND)
	if not success:
		printerr('connection would create an illegal cycle, cancelling connection')
		return

	var cable_start = voxel_world.coordinate_to_position(from_coords) + from_output_offset
	var cable_end = voxel_world.coordinate_to_position(to_coords) + to_input_offset
	var cable = Cable.create(cable_start, cable_end)
	self.add_child(cable)
	$CircuitSimulation.register_cable(from_coords, cable)

func _on_player_reset_position():
	player.position = player_initial_position
	player.velocity = Vector3.ZERO
