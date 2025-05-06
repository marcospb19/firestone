class_name VoxelWorld extends MeshInstance3D

signal updated

enum Face { FRONT, RIGHT, BACK, LEFT, TOP, BOTTOM }
enum BlockKind { DIRT, STONE, GATE_AND }

const FACE_TRIANGLES: Dictionary[Face, Array] = {
	Face.FRONT: [[0, 4, 5], [0, 5, 1]],
	Face.RIGHT: [[1, 5, 6], [1, 6, 2]],
	Face.BACK: [[2, 6, 7], [2, 7, 3]],
	Face.LEFT: [[3, 7, 4], [3, 4, 0]],
	Face.TOP: [[4, 7, 6], [4, 6, 5]],
	Face.BOTTOM: [[0, 1, 2], [0, 2, 3]],
}

const VERTICES_PER_BLOCK := 6 * 6
const CUBE_VERTICES_MAPPING: Array[Vector3] = [
	Vector3(0.0, 0.0, 1.0),
	Vector3(1.0, 0.0, 1.0),
	Vector3(1.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.0, 1.0, 1.0),
	Vector3(1.0, 1.0, 1.0),
	Vector3(1.0, 1.0, 0.0),
	Vector3(0.0, 1.0, 0.0),
]

const UVS_PER_BLOCK := 6 * 6
const BLOCKS_TEXTURE_UV_OFFSET: Dictionary[BlockKind, Vector2] = {
	BlockKind.STONE: Vector2(0.0, 0.0),
	BlockKind.DIRT: Vector2(0.25, 0.0),
	BlockKind.GATE_AND: Vector2(0.5, 0.0),
}

const NORMALS_PER_BLOCK := 6 * 6
const FACE_NORMALS: Dictionary[Face, Vector3i] = {
	Face.FRONT: Vector3i.BACK, # flipped?
	Face.RIGHT: Vector3i.RIGHT,
	Face.BACK: Vector3i.FORWARD, # flipped?
	Face.LEFT: Vector3i.LEFT,
	Face.TOP: Vector3i.UP,
	Face.BOTTOM: Vector3i.DOWN,
}
const BLOCKS_MATERIAL: StandardMaterial3D = preload("res://materials/blocks_material.tres")

var surface_array := []
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()

var block_indices: Dictionary[Vector3i, int] = {}
# Behaves like a Stack, enables accessing element of block_indices with greatest index
var block_positions := PackedVector3Array()

var update_pending := false

func _init():
	mesh = ArrayMesh.new()
	surface_array.resize(Mesh.ARRAY_MAX)

func add_block(pos: Vector3i, kind: BlockKind):
	print("vertices.size() = ", vertices.size())
	print("normals.size() = ", normals.size())
	print("uvs.size() = ", uvs.size())
	print(UVS_PER_BLOCK)
	print(block_positions.size())
	print(UVS_PER_BLOCK * block_positions.size())

	if block_indices.has(pos):
		remove_block(pos)

	block_indices.set(pos, block_indices.size())
	block_positions.append(pos)

	# Pela checagem de vizinhos, o add face coloca uma quantidade dinâmica de
	# elementos nos arrays

	# Por conta disso, um swap_remove naive que assume tamanho fixo não vai
	# funcionar, preciso brainstormar como vou resolver


	var uv_offset = BLOCKS_TEXTURE_UV_OFFSET[kind]
	if not has_neighbor(Face.FRONT, pos):
		add_face(Face.FRONT, pos, uv_offset)
	if not has_neighbor(Face.RIGHT, pos):
		add_face(Face.RIGHT, pos, uv_offset)
	if not has_neighbor(Face.BACK, pos):
		add_face(Face.BACK, pos, uv_offset)
	if not has_neighbor(Face.LEFT, pos):
		add_face(Face.LEFT, pos, uv_offset)
	if not has_neighbor(Face.TOP, pos):
		add_face(Face.TOP, pos, uv_offset)
	if not has_neighbor(Face.BOTTOM, pos):
		add_face(Face.BOTTOM, pos, uv_offset)
	enqueue_mesh_update()

func remove_block(remove_pos: Vector3i):
	var remove_index := block_indices[remove_pos]
	var last_pos := Vector3i(block_positions[-1])
	var last_index := block_indices[last_pos]

	block_indices.erase(remove_pos)
	block_positions.remove_at(block_positions.size() - 1)

	# Do the equivalent of Rust's Vec::swap_remove for stable deletion
	if last_index != remove_index:
		for i in range(VERTICES_PER_BLOCK):
			vertices[(VERTICES_PER_BLOCK + 1) * remove_index - i] = vertices[-i]
		for i in range(NORMALS_PER_BLOCK):
			normals[(NORMALS_PER_BLOCK + 1) * remove_index - i] = normals[-i]
		for i in range(UVS_PER_BLOCK):
			uvs[(UVS_PER_BLOCK + 1) * remove_index - i] = uvs[-i]
	vertices.resize(block_positions.size() * VERTICES_PER_BLOCK)
	normals.resize(block_positions.size() * NORMALS_PER_BLOCK)
	uvs.resize(block_positions.size() * UVS_PER_BLOCK)
	enqueue_mesh_update()

func enqueue_mesh_update():
	if not update_pending:
		if not $UpdateTimer.is_stopped() or $UpdateTimer.time_left > 0.05:
			update_pending = true
			await $UpdateTimer.timeout
			update_pending = false
		$UpdateTimer.start(0.05)
		$UpdateTimer.paused = false
		commit_mesh_surface()


func has_neighbor(face: Face, pos: Vector3i) -> bool:
	var neighbor_position = pos + FACE_NORMALS[face]
	return block_indices.has(neighbor_position)

func add_face(face: Face, pos: Vector3i, uv_offset: Vector2):
	for triangle in FACE_TRIANGLES[face]:
		for vertex_index in triangle:
			var vertex = CUBE_VERTICES_MAPPING[vertex_index]
			vertices.append(vertex + Vector3(pos))
			normals.append(Vector3(FACE_NORMALS[face]))

	uvs.append(uv_offset + Vector2(0.0, 0.0))
	uvs.append(uv_offset + Vector2(0.25, 0.0))
	uvs.append(uv_offset + Vector2(0.25, 0.25))
	uvs.append(uv_offset + Vector2(0.0, 0.0))
	uvs.append(uv_offset + Vector2(0.25, 0.25))
	uvs.append(uv_offset + Vector2(0.0, 0.25))

func commit_mesh_surface():
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	mesh.surface_set_material(0, BLOCKS_MATERIAL)
	updated.emit()
