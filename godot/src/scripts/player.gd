extends CharacterBody3D

@export_subgroup("Properties")
@export var movement_speed := 4.0
@export var jump_strength := 8.0
@export var gravity := 25.0

signal add_block(at_offset: Vector3, face_kind: VoxelWorld.FaceKind, look_direction: Vector3)
signal remove_block(at_offset: Vector3)
signal reset_position
signal connect_faces(from: Vector3, from_face: VoxelWorld.Face, to: Vector3, to_face: VoxelWorld.Face)

const RUN_MULTIPLIER := 1.4
const DOUBLE_JUMP_TOGGLE_DELAY := 0.3
const BLOCK_PLACE_DELAY := 0.2
const BLOCK_FAST_PLACE_DELAY := 0.2 / 3.0
const COOLDOWN_AFTER_FAST_PLACE := 0.5
const MOUSE_SENSITIVITY := 0.00065

var health := 100
var movement_velocity: Vector3
var is_running := false
var edit_block_timer: SceneTreeTimer
var is_flying := true
var is_flying_toggle_timer: SceneTreeTimer
var is_zooming := false
var hotbar := Hotbar.new() # Tells what blocks are in what position, not the best abstraction
var selected_block: int:
	set(value):
		selected_block = value
		ui.update_selected_block(value)

var pending_connection_pos = null
var pending_connection_face = null

@onready var ui = $InGameUI
@onready var camera: Camera3D = $Head/Camera
@onready var raycast: RayCast3D = $Head/Camera/RayCast

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Engine.max_fps = 240
	Utils.set_main_camera(camera)
	edit_block_timer = self.get_tree().create_timer(0)
	is_flying_toggle_timer = self.get_tree().create_timer(0)
	selected_block = 0

func _input(event):
	if not Utils.is_mouse_captured():
		return
	if event is InputEventMouseMotion:
		var zoom_multiplier = 1.0 / 3.0 if is_zooming else 1.0
		var rotation_diff = MOUSE_SENSITIVITY * event.relative * zoom_multiplier
		rotation.y -= rotation_diff.x
		# By not looking straight down or up, we can always tell what direction the user is facing
		# this is useful to know how to orient placed blocks
		const VERTICAL_LIMIT := deg_to_rad(90.0 - 0.00001)
		camera.rotation.x = clampf(camera.rotation.x - rotation_diff.y, -VERTICAL_LIMIT, VERTICAL_LIMIT)
	elif event.is_pressed():
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				selected_block = (selected_block + 1) % 9
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				selected_block = (selected_block + 8) % 9
		elif event is InputEventKey:
			var number = int(event.as_text_keycode()) # crazy conversion
			if number >= 1:
				selected_block = number - 1

func _physics_process(delta: float):
	if Utils.is_mouse_captured():
		if Input.is_action_just_pressed("reset"):
			reset_position.emit()
		handle_movement(delta)
		handle_mouse_clicks()
		if Input.is_action_just_pressed("paint-face"):
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

		handle_zooming()
	self.move_and_slide()

func handle_movement(delta: float):
	if Input.is_action_just_pressed("jump"):
		if is_flying_toggle_timer.time_left > 0.0:
			is_flying = not is_flying
		is_flying_toggle_timer = self.get_tree().create_timer(DOUBLE_JUMP_TOGGLE_DELAY)

	if is_flying:
		var y_multiplier = int(Input.is_action_pressed("jump")) - int(Input.is_action_pressed("ctrl"))
		velocity.y = jump_strength * y_multiplier
	else:
		velocity.y -= gravity * delta
		if self.is_on_floor():
			velocity.y = 0.0
			if Input.is_action_pressed("jump"):
				velocity.y = max(jump_strength, velocity.y + jump_strength / 2.0)

	var input = Input.get_vector("move-left", "move-right", "move-forward", "move-back")
	var run_multiplier := 1.0 + float(Input.is_action_pressed("shift"))
	var wasd_movement := input.limit_length(1.0) * movement_speed * run_multiplier
	velocity = Vector3(wasd_movement.x, velocity.y, wasd_movement.y)
	if velocity.z < 0.0:
		velocity.z *= RUN_MULTIPLIER
	velocity = transform.basis * velocity

var is_fast_removing := false
var is_fast_adding := false
# If player holds to add blocks, make sure they're all facing the same direction
var add_block_look_direction

func handle_mouse_clicks():
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
		try_edit_block(true, false)
	elif is_fast_adding:
		try_edit_block(true, true)
	elif should_slow_remove:
		try_edit_block(false, false)
	elif should_slow_add:
		try_edit_block(false, true)
	elif not left and not right:
		add_block_look_direction = null

func try_edit_block(fast: bool, is_add: bool):
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
		var block = hotbar.access(selected_block)
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

func handle_zooming():
	if Input.is_action_just_pressed("zoom"):
		is_zooming = not is_zooming
		if is_zooming:
			previous_fov = camera.fov
			camera.set_fov(previous_fov / 3.0)
		else:
			assert(previous_fov != null)
			camera.set_fov(previous_fov)
			previous_fov = null
