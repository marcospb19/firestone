extends Node3D

const BLOCK_WIDTH := 1.0
const GRID_LAYERS := [15, 16, 20, 21]
const BLOCKS := [
	preload("res://src/blocks/dirt.tscn"),
	preload("res://src/blocks/stone.tscn"),
	preload("res://src/gates/and.tscn"),
]

@onready var player = $Player
@onready var player_initial_position = player.position

var blocks_container: Node3D
var blocks: Dictionary[Vector3i, CSGPrimitive3D] = {}

func _ready():
	blocks_container = Node3D.new()
	self.add_child(blocks_container)

	var last_layer := 0
	for i in len(GRID_LAYERS):
		var layer: int = GRID_LAYERS[i]
		for x in range(layer):
			for z in range(layer):
				if x < last_layer and z < last_layer:
					continue
				add_block_at(Vector3(x, i, z), 0)
				add_block_at(Vector3(-x, i, z), 0)
				add_block_at(Vector3(x, i, -z), 0)
				add_block_at(Vector3(-x, i, -z), 0)
		last_layer = layer

# Only works cause BLOCK_WIDTH == 1.0, TODO: maybe use Vector3.snapped?
func position_to_coordinate(pos: Vector3) -> Vector3i:
	return pos.floor()

func add_block_at_world_offset(pos: Vector3, selected_block: int, look_direction: Vector3):
	add_block_at(position_to_coordinate(pos), selected_block, look_direction)

func remove_block_at_world_offset(pos: Vector3):
	remove_block_at(position_to_coordinate(pos))

func add_block_at(coordinate: Vector3i, block_index: int, look_direction: Vector3 = Vector3.FORWARD):
	if block_index >= BLOCKS.size():
		return
	var block: CSGPrimitive3D = BLOCKS[block_index].instantiate()
	block.position = (Vector3(coordinate) + Vector3.ONE / 2.0) * Utils.BLOCK_WIDTH

	# Don't place a block if it collides with the player
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = BoxShape3D.new()
	params.transform = Transform3D(Basis.IDENTITY, block.position)
	var collisions = self.get_world_3d().get_direct_space_state().intersect_shape(params, 2)
	for collision in collisions:
		if collision["rid"] == $Player.get_rid():
			return

	remove_block_at(coordinate)
	blocks_container.add_child(block)

	# Rotate based on the look direction
	block.basis = look_direction_to_block_basis(look_direction)

	blocks[coordinate] = block

func remove_block_at(coordinate: Vector3i):
	var block = blocks.get(coordinate)
	if block != null:
		blocks_container.remove_child(block)
		blocks.erase(coordinate)

func _on_player_reset_position():
	player.position = player_initial_position
	player.velocity = Vector3.ZERO

func look_direction_to_block_basis(look: Vector3) -> Basis:
	look = -look # Block will face away from player
	look.y = 0.0 # Never aim blocks down or up, for now
	look = look.normalized() # Compensate the fact that we zeroed `y`
	var direction = look.snapped(Vector3.ONE * sqrt(2.0)).normalized() # Snap to one of the four directions
	return Basis.looking_at(direction * 1_000_000, Vector3.UP)
