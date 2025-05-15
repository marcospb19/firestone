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
					add_block_at(coordinate, VoxelWorld.BlockKind.DIRT)

func add_block_at_world_offset(pos: Vector3, block_kind: VoxelWorld.BlockKind, look_direction: Vector3):
	add_block_at(position_to_coordinate(pos), block_kind, look_direction)

func remove_block_at_world_offset(pos: Vector3):
	remove_block_at(position_to_coordinate(pos))

func add_block_at(coordinate: Vector3i, block_kind: VoxelWorld.BlockKind, look_direction: Vector3 = Vector3.FORWARD):
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
	$VoxelWorld.add_block(coordinate, block_kind)

	if block_kind == VoxelWorld.BlockKind.GATE_AND:
		$VoxelWorld.update_face_uv($VoxelWorld.index_to_position.size() - 1, look_direction_to_face(look_direction), Vector2(0.0, 0.25))
	$VoxelWorld.disable_updates = false
	$VoxelWorld.enqueue_mesh_update()

	#remove_block_at(coordinate)
	# # Rotate based on the look direction
	#block.cube_mesh.basis = look_direction_to_block_basis(look_direction)

func remove_block_at(coordinate: Vector3i):
	$VoxelWorld.remove_block(coordinate)
	#blocks_container.remove_child(block.cube_collision)
	#blocks.erase(coordinate)

func _on_player_reset_position():
	player.position = player_initial_position
	player.velocity = Vector3.ZERO

func look_direction_to_face(look: Vector3) -> VoxelWorld.Face:
	look.y = 0.0 # Never aim blocks down or up, for now
	look = look.normalized() # Compensate the fact that we zeroed `y`
	var direction = look.snapped(Vector3.ONE * sqrt(2.0)).normalized() # Snap to one of the four directions
	#direction = -direction # Block will face away from player # TODO: review this
	return VoxelWorld.FACE_NORMALS_REVERSED[Vector3i(direction)]

func _on_voxel_world_updated() -> void:
	$StaticBody3D/CollisionShape3D.shape = $VoxelWorld.mesh.create_trimesh_shape()

func _on_player_connect_faces(from: Vector3, from_face: VoxelWorld.Face, to: Vector3, to_face: VoxelWorld.Face):
	var from_coords = position_to_coordinate(from)
	var to_coords = position_to_coordinate(to)
	$VoxelWorld.update_face_uv($VoxelWorld.position_to_index[from_coords], from_face, Vector2(0.0, 0.25))
	$VoxelWorld.update_face_uv($VoxelWorld.position_to_index[to_coords], to_face, Vector2(0.0, 0.25))
	from = coordinate_to_position(from_coords)
	to = coordinate_to_position(to_coords)

	var cable_start = from + VoxelWorld.FACE_NORMALS[from_face] / 2.0
	var cable_end = to + VoxelWorld.FACE_NORMALS[to_face] / 2.0
	var distance = (cable_start - cable_end).length() + 0.1

	var cable = CSGBox3D.new()
	self.add_child(cable)
	cable.look_at(cable_start.direction_to(cable_end))
	cable.size = Vector3(0.1, 0.1, distance)
	cable.position = (cable_start + cable_end) / 2.0

	cable.material = StandardMaterial3D.new()
	cable.material.albedo_color = Color.YELLOW
	cable.material.vertex_color_use_as_albedo = true

# Only works cause BLOCK_WIDTH == 1.0, TODO: maybe use Vector3.snapped?
func position_to_coordinate(pos: Vector3) -> Vector3i:
	return pos.floor()

func coordinate_to_position(coord: Vector3i) -> Vector3:
	return Vector3(coord) + Vector3.ONE * 0.5
