extends CharacterBody3D

@export_subgroup("Properties")
@export var movement_speed := 3.0
@export var jump_strength := 6.0
@export var gravity := 20.0

const RUN_MULTIPLIER := 1.4

var mouse_sensitivity := 0.00065
var health := 100
var movement_velocity: Vector3
var previously_floored := false

@onready var ui = $InGameUI
@onready var camera: Camera3D = $Head/Camera
@onready var raycast: RayCast3D = $Head/Camera/RayCast

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Engine.max_fps = 240
	Utils.set_main_camera(camera)

func apply_rotation(diff: Vector2):
	rotation.y -= diff.x
	camera.rotation.x = clampf(camera.rotation.x - diff.y, deg_to_rad(-90.0), deg_to_rad(90.0))

func _physics_process(delta: float):
	velocity.y -= gravity * delta
	if Utils.is_mouse_captured():
		handle_controls(delta)
	self.move_and_slide()
	previously_floored = self.is_on_floor()

func _input(event):
	if event is InputEventMouseMotion and Utils.is_mouse_captured():
		apply_rotation(mouse_sensitivity * event.relative)

func handle_controls(delta: float):
	handle_click()
	handle_action_jump_and_jet(delta)

	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement := Vector3(input.x, 0, input.y).limit_length(1.0) * movement_speed

	# Apply run multiplier if moving forward
	if movement.z < 0.0:
		movement.z *= RUN_MULTIPLIER

	movement.y = velocity.y
	velocity = transform.basis * movement

func handle_action_jump_and_jet(_delta: float):
	if self.is_on_floor():
		velocity.y = 0.0

	if Input.is_action_pressed("jump"):
		if self.is_on_floor():
			velocity.y = max(jump_strength, velocity.y + jump_strength / 2.0)

func handle_click():
	if Input.is_action_pressed("shoot"):
		raycast.force_raycast_update()
		if raycast.is_colliding():
			# var collider = raycast.get_collider()
			pass
