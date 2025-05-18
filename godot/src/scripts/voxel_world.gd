class_name VoxelWorld extends MeshInstance3D

signal updated

enum Face { FRONT, RIGHT, BACK, LEFT, TOP, BOTTOM }
enum FaceKind {
	DIRT,
	STONE,
	NOT_BLANK,
	NOT_INPUT,
	NOT_OUTPUT,
	AND_BLANK,
	AND_INPUT,
	AND_OUTPUT,
	OR_BLANK,
	OR_INPUT,
	OR_OUTPUT,
}
const BLOCKS_MATERIAL: StandardMaterial3D = preload("res://src/materials/blocks_material.tres")

const BLOCKS_TEXTURE_UV_OFFSET: Dictionary[FaceKind, Vector2] = {
	FaceKind.DIRT: Vector2(0.0, 0.0),
	FaceKind.STONE: Vector2(0.25, 0.0),
	FaceKind.NOT_BLANK: Vector2(0.0, 0.25),
	FaceKind.NOT_INPUT: Vector2(0.25, 0.25),
	FaceKind.NOT_OUTPUT: Vector2(0.5, 0.25),
	FaceKind.AND_BLANK: Vector2(0.0, 0.5),
	FaceKind.AND_INPUT: Vector2(0.25, 0.5),
	FaceKind.AND_OUTPUT: Vector2(0.5, 0.5),
	FaceKind.OR_BLANK: Vector2(0.0, 0.75),
	FaceKind.OR_INPUT: Vector2(0.25, 0.75),
	FaceKind.OR_OUTPUT: Vector2(0.5, 0.75),
}
const VERTICES_PER_BLOCK := 6 * 6
const FACE_TRIANGLES: Dictionary[Face, Array] = {
	Face.FRONT: [[0, 4, 5], [0, 5, 1]],
	Face.RIGHT: [[1, 5, 6], [1, 6, 2]],
	Face.BACK: [[2, 6, 7], [2, 7, 3]],
	Face.LEFT: [[3, 7, 4], [3, 4, 0]],
	Face.TOP: [[4, 7, 6], [4, 6, 5]],
	Face.BOTTOM: [[0, 1, 2], [0, 2, 3]],
}
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

const FACE_NORMALS: Dictionary[Face, Vector3i] = {
	Face.FRONT: Vector3i.BACK,
	Face.RIGHT: Vector3i.RIGHT,
	Face.BACK: Vector3i.FORWARD,
	Face.LEFT: Vector3i.LEFT,
	Face.TOP: Vector3i.UP,
	Face.BOTTOM: Vector3i.DOWN,
}
const FACE_NORMALS_REVERSED: Dictionary[Vector3i, Face] = {
	Vector3i.FORWARD: Face.BACK,
	Vector3i.RIGHT: Face.RIGHT,
	Vector3i.BACK: Face.FRONT,
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

var blocks: Dictionary[Vector3i, BlockInfo] = {}
var block_positions := PackedVector3Array() # Used as a stack

class BlockInfo:
	var index: int
	var face_kinds: Array[FaceKind]

	func _init(index_: int, face_kinds_: Array[FaceKind]):
		index = index_
		face_kinds = face_kinds_

func _init():
	mesh = ArrayMesh.new()
	surface_array.resize(Mesh.ARRAY_MAX)

func add_block(pos: Vector3i, face_kind: FaceKind):
	if blocks.has(pos):
		remove_block(pos)

	blocks[pos] = BlockInfo.new(blocks.size(), face_kind_repeat_array(face_kind))
	block_positions.append(pos)

	var uv_offset = BLOCKS_TEXTURE_UV_OFFSET[face_kind]
	# # Pela checagem de vizinhos, o add face coloca uma quantidade dinâmica de
	# # elementos nos arrays
	# #
	# # Por conta disso, um swap_remove naive que assume tamanho fixo não vai
	# # funcionar, preciso brainstormar como vou resolver
	# #
	# # Seria mais fácil resolver isso depois, quando esse código
	# # inevitavelmente for portado para Rust (no futuuuro)
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
	var block_to_remove := blocks[remove_pos]
	var last_pos := Vector3i(block_positions[-1])
	var last_index := blocks[last_pos].index
	blocks.erase(remove_pos)
	block_positions.remove_at(block_positions.size() - 1)

	if last_index != block_to_remove.index:
		# Last element was swapped, update its new index
		block_positions.set(block_to_remove.index, last_pos)
		blocks[last_pos].index = block_to_remove.index

	Utils.swap_remove_window(vertices, block_to_remove.index, VERTICES_PER_BLOCK)
	Utils.swap_remove_window(normals, block_to_remove.index, VERTICES_PER_BLOCK)
	Utils.swap_remove_window(uvs, block_to_remove.index, VERTICES_PER_BLOCK)
	enqueue_mesh_update()

func has_neighbor(face: Face, pos: Vector3i) -> bool:
	var neighbor_position = pos + FACE_NORMALS[face]
	return blocks.has(neighbor_position)

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

func update_face_uv(coords: Vector3i, face: Face, face_kind: FaceKind):
	blocks[coords].face_kinds[face] = face_kind
	var uv_offset = BLOCKS_TEXTURE_UV_OFFSET[face_kind]
	var index_start = blocks[coords].index * VERTICES_PER_BLOCK + (face as int) * 6
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

static func is_kind_gate(kind: FaceKind) -> bool:
	match kind:
		FaceKind.DIRT, FaceKind.STONE:
			return false
		_:
			return true

static func is_kind_input(kind: FaceKind) -> bool:
	match kind:
		FaceKind.NOT_INPUT, FaceKind.AND_INPUT, FaceKind.OR_INPUT:
			return true
		_:
			return false

static func is_kind_output(kind: FaceKind) -> bool:
	match kind:
		FaceKind.NOT_OUTPUT, FaceKind.AND_OUTPUT, FaceKind.OR_OUTPUT:
			return true
		_:
			return false

static func blank_to_input(kind: FaceKind) -> FaceKind:
	return (kind + 1) as FaceKind

static func blank_to_output(kind: FaceKind) -> FaceKind:
	return (kind + 2) as FaceKind

func face_kind_from_block_face(coords: Vector3i, face: Face) -> FaceKind:
	return blocks[coords].face_kinds[face]

static func face_kind_repeat_array(face_kind: FaceKind) -> Array[FaceKind]:
	return [
		face_kind, face_kind, face_kind,
		face_kind, face_kind, face_kind,
	]
