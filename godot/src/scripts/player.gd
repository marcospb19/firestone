extends CharacterBody3D

@export_subgroup("Properties")
@export var jump_strength := 8.0
@export var gravity := 25.0

signal add_block(at_offset: Vector3, block_kind: VoxelWorld.BlockKind, look_direction: Vector3)
signal remove_block(at_offset: Vector3)
signal reset_position
signal connect_faces(from: Vector3, from_face: VoxelWorld.Face, to: Vector3, to_face: VoxelWorld.Face)

const MOVEMENT_SPEED := 6.0
const RUN_SPEED_MULTIPLIER := 1.4
const FLYING_SPEED_MULTIPLIER := 1.4

const DOUBLE_JUMP_TOGGLE_DELAY := 0.3
const BLOCK_PLACE_DELAY := 0.2
const BLOCK_FAST_PLACE_DELAY := BLOCK_PLACE_DELAY / 3.0
const COOLDOWN_AFTER_FAST_PLACE := 0.5
const MOUSE_SENSITIVITY := 0.00065

var edit_block_timer: SceneTreeTimer
var is_flying := false
var is_flying_toggle_timer: SceneTreeTimer
var is_zooming := false
var hotbar := Hotbar.new() # Tells what blocks are in what position, not the best abstraction

var pending_connection_pos = null
var pending_connection_face = null

@onready var camera: Camera3D = $Head/Camera
@onready var raycast: RayCast3D = $Head/Camera/RayCast
@onready var player_ui: Control = $PlayerUI

func _ready():
	Utils.set_main_camera(camera)
	Input.set_use_accumulated_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Engine.max_fps = Utils2.refresh_rate_to_fps(DisplayServer.screen_get_refresh_rate())

	edit_block_timer = self.get_tree().create_timer(0)
	is_flying_toggle_timer = self.get_tree().create_timer(0)
	for i in hotbar.HOTBAR_ELEMENTS.size():
		player_ui.update_hotbar_preview(i, hotbar.HOTBAR_ELEMENTS[i])

func _input(event):
	if not Utils.is_mouse_captured():
		return
	if event is InputEventMouseMotion:
		var zoom_multiplier = 1.0 / 3.0 if is_zooming else 1.0
		var rotation_diff = MOUSE_SENSITIVITY * event.relative * zoom_multiplier
		rotation.y -= rotation_diff.x
		# By not looking straight down or up, we can always tell what direction the user is facing
		# this is useful to know how to orient placed blocks
		const VERTICAL_LIMIT := deg_to_rad(90.0 - Utils.EPSILON)
		camera.rotation.x = clampf(camera.rotation.x - rotation_diff.y, -VERTICAL_LIMIT, VERTICAL_LIMIT)
	elif event.is_pressed():
		if hotbar.handle_input_event(event):
			player_ui.update_selected_block(hotbar.get_selected_index())

func _process(delta: float):
	__apply_gravity(delta)
	if Utils.is_mouse_captured():
		if Input.is_action_just_pressed("f1"):
			player_ui.f1_hide_hud = not player_ui.f1_hide_hud
		if Input.is_action_just_pressed("r"):
			reset_position.emit()
		__handle_movement()
		__handle_block_manipulation()
		__handle_block_connecting()
		__handle_zooming()
	self.move_and_slide()

func __handle_movement():
	if Input.is_action_just_pressed("jump"):
		if is_flying_toggle_timer.time_left > 0.0:
			is_flying = not is_flying
		is_flying_toggle_timer = self.get_tree().create_timer(DOUBLE_JUMP_TOGGLE_DELAY)

	if is_flying:
		var y_multiplier = int(Input.is_action_pressed("jump")) - int(Input.is_action_pressed("ctrl"))
		self.velocity.y = jump_strength * y_multiplier
	else:
		if self.is_on_floor():
			self.velocity.y = 0.0
			if Input.is_action_pressed("jump"):
				self.velocity.y = max(jump_strength, self.velocity.y + jump_strength / 2.0)

	var input = Input.get_vector("move-left", "move-right", "move-forward", "move-back")
	var speed := (
		MOVEMENT_SPEED
			* (RUN_SPEED_MULTIPLIER if Input.is_action_pressed("shift") else 1.0)
			* (FLYING_SPEED_MULTIPLIER if is_flying else 1.0)
	)
	var wasd_movement := input.limit_length(1.0) * speed
	self.velocity = Vector3(wasd_movement.x, self.velocity.y, wasd_movement.y)
	if self.velocity.z < 0.0:
		self.velocity.z *= RUN_SPEED_MULTIPLIER
	self.velocity = self.transform.basis * self.velocity

func __handle_block_connecting():
	if Input.is_action_just_pressed("e"):
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var normal = raycast.get_collision_normal()
			var point = raycast.get_collision_point() - normal * 0.01
			var face = VoxelWorld.FACE_NORMALS_REVERSED[Vector3i(normal)]
			if pending_connection_face == null:
				pending_connection_face = face
				pending_connection_pos = point
			else:
				connect_faces.emit(pending_connection_pos, pending_connection_face, point, face)
				pending_connection_face = null
				pending_connection_pos = null

var is_fast_removing := false
var is_fast_adding := false
# If player holds to add blocks, make sure they're all facing the same direction
var add_block_look_direction

func __handle_block_manipulation():
	var left = Input.is_action_pressed("mouse-left")
	var right = Input.is_action_pressed("mouse-right")
	var pressed_left = Input.is_action_just_pressed("mouse-left")
	var pressed_right = Input.is_action_just_pressed("mouse-right")
	var released_left = Input.is_action_just_released("mouse-left")
	var released_right = Input.is_action_just_released("mouse-right")

	if pressed_left or pressed_right:
		edit_block_timer.time_left = 0.0
	if released_left or released_right:
		edit_block_timer.time_left = COOLDOWN_AFTER_FAST_PLACE

	is_fast_removing = left and (is_fast_removing and right or pressed_right)
	is_fast_adding = right and (is_fast_adding and left or pressed_left)
	if is_fast_removing and is_fast_adding:
		is_fast_adding = false
		is_fast_removing = false

	var should_slow_remove = pressed_left or (left and edit_block_timer.time_left == 0.0)
	var should_slow_add = pressed_right or (right and edit_block_timer.time_left == 0.0)

	if is_fast_removing:
		__try_edit_block(true, false)
	elif is_fast_adding:
		__try_edit_block(true, true)
	elif should_slow_remove:
		__try_edit_block(false, false)
	elif should_slow_add:
		__try_edit_block(false, true)
	elif not left and not right:
		add_block_look_direction = null

func __try_edit_block(fast: bool, is_add: bool):
	if edit_block_timer.time_left != 0.0:
		return

	raycast.force_raycast_update()
	if not raycast.is_colliding():
		return

	if is_add and add_block_look_direction == null:
		add_block_look_direction = -camera.global_basis.z
	elif not is_add:
		add_block_look_direction = null

	var point = raycast.get_collision_point()
	var normal = raycast.get_collision_normal()
	if is_add:
		var block = hotbar.get_selected()
		if block == null:
			return
		add_block.emit(point + normal * 0.01, block, add_block_look_direction)
	else:
		remove_block.emit(point - normal * 0.01)
	if fast:
		edit_block_timer = self.get_tree().create_timer(BLOCK_FAST_PLACE_DELAY)
	else:
		edit_block_timer = self.get_tree().create_timer(BLOCK_PLACE_DELAY)

var previous_fov = null

func __handle_zooming():
	if Input.is_action_just_pressed("zoom"):
		is_zooming = not is_zooming
		if is_zooming:
			previous_fov = camera.fov
			camera.set_fov(previous_fov / 3.0)
		else:
			assert(previous_fov != null)
			camera.set_fov(previous_fov)
			previous_fov = null

func __apply_gravity(delta: float):
	if not is_flying:
		self.velocity.y -= gravity * delta
