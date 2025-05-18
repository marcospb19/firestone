extends Node3D

const DIMENSIONS := Vector3i(16, 1, 16)
const BLOCK_WIDTH := 1.0
const CUT_OFF := 0.0

@onready var player = $Player
@onready var player_initial_position = player.position

func _ready():
	var random = FastNoiseLite.new()
	random.noise_type = FastNoiseLite.TYPE_SIMPLEX

	for x in DIMENSIONS.x:
		for y in DIMENSIONS.y:
			for z in DIMENSIONS.z:
				#var rand = random.get_noise_3d(x, y, z)
				#if rand >= CUT_OFF:
				if randf() > CUT_OFF:
					var coordinate = Vector3i(x, y, z)
					coordinate -= DIMENSIONS / 2 # centralize
					#coordinate.z -= DIMENSIONS.z / 1.8 + 5
					coordinate.y -= 2
					add_block_at(coordinate, VoxelWorld.FaceKind.STONE)

func add_block_at_world_offset(pos: Vector3, face_kind: VoxelWorld.FaceKind, look_direction: Vector3):
	add_block_at(position_to_coordinate(pos), face_kind, look_direction)

func remove_block_at_world_offset(pos: Vector3):
	remove_block_at(position_to_coordinate(pos))

func add_block_at(coordinate: Vector3i, face_kind: VoxelWorld.FaceKind, look_direction: Vector3 = Vector3.FORWARD):
	# Don't place a block if it collides with the player
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = BoxShape3D.new()
	params.shape.size = Vector3.ONE * 0.99
	params.transform = Transform3D(Basis.IDENTITY, coordinate_to_position(coordinate))
	var collisions = self.get_world_3d().get_direct_space_state().intersect_shape(params, 2)
	for collision in collisions:
		if collision["rid"] == $Player.get_rid():
			return

	$VoxelWorld.disable_updates = true
	$VoxelWorld.add_block(coordinate, face_kind)

	if VoxelWorld.is_kind_gate(face_kind):
		$VoxelWorld.update_face_uv($VoxelWorld.block_positions[-1], look_direction_to_face(look_direction), VoxelWorld.blank_to_output(face_kind))
		$VoxelWorld.update_face_uv($VoxelWorld.block_positions[-1], look_direction_to_face(-look_direction), VoxelWorld.blank_to_input(face_kind))
	$VoxelWorld.disable_updates = false
	$VoxelWorld.enqueue_mesh_update()

func remove_block_at(coordinate: Vector3i):
	$VoxelWorld.remove_block(coordinate)

func _on_player_reset_position():
	player.position = player_initial_position
	player.velocity = Vector3.ZERO

func look_direction_to_face(look: Vector3) -> VoxelWorld.Face:
	look.y = 0.0 # Blocks can't face up or down
	look = look.normalized() # Compensate the zeroed `y`
	var direction = look.snappedf(sqrt(2.0))
	if not is_equal_approx(absf(direction.x) + absf(direction.y) + absf(direction.z), 1.0):
		# If you're perfectly aiming at Vector3(sqrt(2.0), 0.0, sqrt(2.0)), you'll be in-between
		# two directions, pick one of them by rotating a little to the right.
		# (since look can't be UP or DOWN, that sum can only be 1.0 or sqrt(2.0)
		direction = look.rotated(Vector3.UP, deg_to_rad(1)).snappedf(sqrt(2.0))
	return VoxelWorld.FACE_NORMALS_REVERSED[Vector3i(direction)]

func _on_voxel_world_updated() -> void:
	$StaticBody3D/CollisionShape3D.shape = $VoxelWorld.mesh.create_trimesh_shape()

func _on_player_connect_faces(from: Vector3, from_face: VoxelWorld.Face, to: Vector3, to_face: VoxelWorld.Face):
	var from_coords = position_to_coordinate(from)
	var to_coords = position_to_coordinate(to)

	if from_coords == to_coords:
		printerr('cant connect block to itself')
		return

	var from_face_kind = $VoxelWorld.face_kind_from_block_face(from_coords, from_face)
	var to_face_kind = $VoxelWorld.face_kind_from_block_face(to_coords, to_face)

	if not VoxelWorld.is_kind_gate(from_face_kind):
		printerr('from is not gate, not connecting')
		return
	if not VoxelWorld.is_kind_gate(to_face_kind):
		printerr('to is not gate, not connecting')
		return

	if not VoxelWorld.is_kind_output(from_face_kind) or not VoxelWorld.is_kind_input(to_face_kind):
		printerr('from is not output, or to is not input')
		return

	$VoxelWorld.update_face_uv(from_coords, from_face, from_face_kind)
	$VoxelWorld.update_face_uv(to_coords, to_face, to_face_kind)
	from = coordinate_to_position(from_coords)
	to = coordinate_to_position(to_coords)

	$CircuitSimulation.connect_blocks(from_coords, to_coords, from_face_kind == VoxelWorld.FaceKind.AND_OUTPUT, to_face_kind == VoxelWorld.FaceKind.AND_INPUT)

	var cable_start = from + VoxelWorld.FACE_NORMALS[from_face] / 2.0
	var cable_end = to + VoxelWorld.FACE_NORMALS[to_face] / 2.0
	var cable = Cable.new(cable_start, cable_end)
	self.add_child(cable)

# Only works cause BLOCK_WIDTH == 1.0, TODO: maybe use Vector3.snapped?
func position_to_coordinate(pos: Vector3) -> Vector3i:
	return pos.floor()

func coordinate_to_position(coord: Vector3i) -> Vector3:
	return Vector3(coord) + Vector3.ONE * 0.5
