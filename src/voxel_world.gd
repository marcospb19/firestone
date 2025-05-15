class_name VoxelWorld extends MeshInstance3D

signal updated

enum Face { FRONT, RIGHT, BACK, LEFT, TOP, BOTTOM }
enum BlockKind { DIRT, STONE, GATE_AND }
const BLOCKS_MATERIAL: StandardMaterial3D = preload("res://materials/blocks_material.tres")

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
const UVS_PER_FACE := 6
const BLOCKS_TEXTURE_UV_OFFSET: Dictionary[BlockKind, Vector2] = {
	BlockKind.STONE: Vector2(0.0, 0.0),
	BlockKind.DIRT: Vector2(0.25, 0.0),
	BlockKind.GATE_AND: Vector2(0.5, 0.0),
}

const NORMALS_PER_BLOCK := 6 * 6
const FACE_NORMALS: Dictionary[Face, Vector3i] = {
	Face.FRONT: Vector3i.BACK,
	Face.RIGHT: Vector3i.RIGHT,
	Face.BACK: Vector3i.FORWARD,
	Face.LEFT: Vector3i.LEFT,
	Face.TOP: Vector3i.UP,
	Face.BOTTOM: Vector3i.DOWN,
}
const FACE_NORMALS_REVERSED: Dictionary[Vector3i, Face] = {
	Vector3i.BACK: Face.FRONT,
	Vector3i.RIGHT: Face.RIGHT,
	Vector3i.FORWARD: Face.BACK,
	Vector3i.LEFT: Face.LEFT,
	Vector3i.UP: Face.TOP,
	Vector3i.DOWN: Face.BOTTOM,
}

var surface_array := []
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var update_pending := false
var disable_updates := false

var index_to_position := PackedVector3Array() # Used as a stack
var position_to_index: Dictionary[Vector3i, int] = {}

func _init():
	mesh = ArrayMesh.new()
	surface_array.resize(Mesh.ARRAY_MAX)

func add_block(pos: Vector3i, kind: BlockKind):
	if position_to_index.has(pos):
		remove_block(pos)

	position_to_index[pos] = position_to_index.size()
	index_to_position.append(pos)

	var uv_offset = BLOCKS_TEXTURE_UV_OFFSET[kind]
	# # Pela checagem de vizinhos, o add face coloca uma quantidade dinâmica de
	# # elementos nos arrays
	# #
	# # Por conta disso, um swap_remove naive que assume tamanho fixo não vai
	# # funcionar, preciso brainstormar como vou resolver
	#if not has_neighbor(Face.FRONT, pos):
		#add_face(Face.FRONT, pos, uv_offset)
	#if not has_neighbor(Face.RIGHT, pos):
		#add_face(Face.RIGHT, pos, uv_offset)
	#if not has_neighbor(Face.BACK, pos):
		#add_face(Face.BACK, pos, uv_offset)
	#if not has_neighbor(Face.LEFT, pos):
		#add_face(Face.LEFT, pos, uv_offset)
	#if not has_neighbor(Face.TOP, pos):
		#add_face(Face.TOP, pos, uv_offset)
	#if not has_neighbor(Face.BOTTOM, pos):
		#add_face(Face.BOTTOM, pos, uv_offset)

	add_face(Face.FRONT, pos, uv_offset)
	add_face(Face.RIGHT, pos, uv_offset)
	add_face(Face.BACK, pos, uv_offset)
	add_face(Face.LEFT, pos, uv_offset)
	add_face(Face.TOP, pos, uv_offset)
	add_face(Face.BOTTOM, pos, uv_offset)
	enqueue_mesh_update()

func remove_block(remove_pos: Vector3i):
	var last_pos := Vector3i(index_to_position[-1])

	var remove_index := position_to_index[remove_pos]
	var last_index := position_to_index[last_pos]

	position_to_index.erase(remove_pos)
	index_to_position.remove_at(index_to_position.size() - 1)

	if last_index != remove_index:
		index_to_position.set(remove_index, last_pos)
		position_to_index[last_pos] = remove_index

	Utils.swap_remove_window(vertices, remove_index, VERTICES_PER_BLOCK)
	Utils.swap_remove_window(normals, remove_index, NORMALS_PER_BLOCK)
	Utils.swap_remove_window(uvs, remove_index, UVS_PER_BLOCK)
	enqueue_mesh_update()

func has_neighbor(face: Face, pos: Vector3i) -> bool:
	var neighbor_position = pos + FACE_NORMALS[face]
	return position_to_index.has(neighbor_position)

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

func update_face_uv(block_index: int, face: Face, uv_offset: Vector2):
	var index_start = block_index * UVS_PER_BLOCK + (face as int) * UVS_PER_FACE
	uvs.set(index_start + 0, uv_offset + Vector2(0.0, 0.0))
	uvs.set(index_start + 1, uv_offset + Vector2(0.25, 0.0))
	uvs.set(index_start + 2, uv_offset + Vector2(0.25, 0.25))
	uvs.set(index_start + 3, uv_offset + Vector2(0.0, 0.0))
	uvs.set(index_start + 4, uv_offset + Vector2(0.25, 0.25))
	uvs.set(index_start + 5, uv_offset + Vector2(0.0, 0.25))
	enqueue_mesh_update()

func enqueue_mesh_update():
	if not update_pending and not disable_updates:
		if not $UpdateTimer.is_stopped() or $UpdateTimer.time_left > 0.05:
			update_pending = true
			await $UpdateTimer.timeout
			update_pending = false
		$UpdateTimer.start(0.05)
		$UpdateTimer.paused = false

		mesh.clear_surfaces()
		if vertices.is_empty():
			return
		surface_array[Mesh.ARRAY_VERTEX] = vertices
		surface_array[Mesh.ARRAY_NORMAL] = normals
		surface_array[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
		mesh.surface_set_material(0, BLOCKS_MATERIAL)
		updated.emit()
