extends Node3D

const DIMENSIONS := Vector3i(2, 1, 2)
const BLOCK_WIDTH := 1.0
const CUT_OFF := 0.0
const GRID_LAYERS := [15, 16, 20, 21]

@onready var player = $Player
@onready var player_initial_position = player.position

func _ready():
	var random = FastNoiseLite.new()
	random.noise_type = FastNoiseLite.TYPE_SIMPLEX

	for x in DIMENSIONS.x:
		for y in DIMENSIONS.y:
			for z in DIMENSIONS.z:
				var rand = random.get_noise_3d(x, y, z)
				if rand > CUT_OFF:
					var coordinate = Vector3i(x, y, z)
					coordinate -= DIMENSIONS / 2 # centralize
					coordinate.z -= 5
					add_block_at(coordinate, VoxelWorld.BlockKind.STONE)

# Only works cause BLOCK_WIDTH == 1.0, TODO: maybe use Vector3.snapped?
func position_to_coordinate(pos: Vector3) -> Vector3i:
	return pos.floor()

func add_block_at_world_offset(pos: Vector3, block_kind: VoxelWorld.BlockKind, look_direction: Vector3):
	add_block_at(position_to_coordinate(pos), block_kind, look_direction)

func remove_block_at_world_offset(pos: Vector3):
	remove_block_at(position_to_coordinate(pos))

func add_block_at(coordinate: Vector3i, block_kind: VoxelWorld.BlockKind, look_direction: Vector3 = Vector3.FORWARD):
	# Don't place a block if it collides with the player
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = BoxShape3D.new()
	params.shape.size = Vector3.ONE * 0.99
	params.transform = Transform3D(Basis.IDENTITY, Vector3(coordinate) + Vector3.ONE * 0.5)
	var collisions = self.get_world_3d().get_direct_space_state().intersect_shape(params, 2)
	for collision in collisions:
		if collision["rid"] == $Player.get_rid():
			return

	$VoxelWorld.add_block(coordinate, block_kind)

	#remove_block_at(coordinate)
	## Rotate based on the look direction
	#block.cube_mesh.basis = look_direction_to_block_basis(look_direction)

func remove_block_at(coordinate: Vector3i):
	$VoxelWorld.remove_block(coordinate)
		#blocks_container.remove_child(block.cube_collision)
		#blocks.erase(coordinate)

func _on_player_reset_position():
	player.position = player_initial_position
	player.velocity = Vector3.ZERO

func look_direction_to_block_basis(look: Vector3) -> Basis:
	look = -look # Block will face away from player
	look.y = 0.0 # Never aim blocks down or up, for now
	look = look.normalized() # Compensate the fact that we zeroed `y`
	var direction = look.snapped(Vector3.ONE * sqrt(2.0)).normalized() # Snap to one of the four directions
	return Basis.looking_at(direction * 1_000_000, Vector3.UP)

func _on_voxel_world_updated() -> void:
	$StaticBody3D/CollisionShape3D.shape = $VoxelWorld.mesh.create_trimesh_shape()
