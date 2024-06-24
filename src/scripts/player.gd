extends CharacterBody3D

# TODO: add bullet tracers
# TODO: re-add weapon model kickback
# TODO: make camera vertical swing respect inertia

signal died

@onready var ui = $InGameUI

@export_subgroup("Properties")
@export var movement_speed := 5.0
@export var jump_strength := 6.0
@export var jet_strength := 23.0

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []

const WEAPON_CONTAINER_OFFSET := Vector3(1.2, -1.1, -2.75)

var weapon_index := 0
var weapon_timers: Array[Timer] = []

var mouse_sensitivity := 0.0008
var gamepad_sensitivity := 0.075

var health := 100

var movement_velocity: Vector3
var previously_floored := false

@onready var camera: Camera3D = $Head/Camera
@onready var raycast: RayCast3D = $Head/Camera/RayCast
@onready var weapon_container: Node3D = $Head/Camera/ViewportContainer/WeaponView/CameraItem/WeaponContainer
@onready var muzzle: AnimatedSprite3D = $Head/Camera/ViewportContainer/WeaponView/CameraItem/WeaponContainer/Muzzle
@onready var sound_footsteps: AudioStreamPlayer = $SoundFootsteps


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	initiate_change_weapon(weapon_index)
	for weapon in weapons:
		var timer := Timer.new()
		timer.wait_time = weapon.firerate_cooldown()
		timer.one_shot = true
		weapon_timers.append(timer)
		self.add_child(timer)


# Rotates player look, input is X and Y diff
func apply_rotation(diff: Vector2):
	# Horizontal rotation
	rotation.y -= diff.x
	# Vertical rotation
	camera.rotation.x = clampf(camera.rotation.x - diff.y, deg_to_rad(-90.0), deg_to_rad(90.0))


func _physics_process(delta: float):
	# apply gravity
	velocity.y -= 20 * delta
	
	if Utils.is_mouse_captured():
		handle_controls(delta)
	
	self.move_and_slide()
	
	if position.y < -10:
		died.emit()
	
	weapon_container.position = lerp(
		weapon_container.position, WEAPON_CONTAINER_OFFSET - (velocity / 30), delta * 10
	)
	
	# Movement sound
	sound_footsteps.stream_paused = true
	
	if self.is_on_floor():
		var trigger_footsteps = abs(velocity.x) > 1 or abs(velocity.z) > 1
		if trigger_footsteps:
			sound_footsteps.stream_paused = false
	
	if self.is_on_floor() and velocity.y > 1 and !previously_floored:
		Audio.play_at("land.ogg")
	previously_floored = self.is_on_floor()


func _input(event):
	# Mouse look control
	if event is InputEventMouseMotion and Utils.is_mouse_captured():
		var mouse_rotation = event.relative * mouse_sensitivity
		apply_rotation(mouse_rotation)


func handle_controls(delta: float):
	handle_action_shoot()
	handle_action_weapon_toggle()
	handle_action_jump_and_jet(delta)
	
	# Flat movement
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement := Vector3(input.x, 0, input.y).limit_length(1.0) * movement_speed
	movement.y = velocity.y
	velocity = transform.basis * movement
	
	# Gamepad look control
	var gamepad_rotation_input := Input.get_vector(
		"look_right", "look_left", "look_down", "look_up"
	)
	var gamepad_rotation = gamepad_rotation_input.limit_length(1.0) * gamepad_sensitivity
	apply_rotation(gamepad_rotation)


func handle_action_jump_and_jet(delta: float):
	if self.is_on_floor():
		velocity.y = 0.0
	
	if Input.is_action_pressed("jump"):
		if self.is_on_floor():
			Audio.play_at_one_of(["jump_a.ogg", "jump_b.ogg", "jump_c.ogg"])
			velocity.y = max(jump_strength, velocity.y + jump_strength / 2.0)
		else:
			velocity.y += jet_strength * delta


func handle_action_shoot():
	if Input.is_action_pressed("shoot") and current_weapon_timer().is_stopped():
		current_weapon_timer().start(current_weapon().firerate_cooldown())
		Audio.play(current_weapon().fire_sound, current_weapon().volume_adjust)
		
		# Reset muzzle animation
		muzzle.play()
		muzzle.rotation_degrees.z = randf_range(0, 90)
		muzzle.scale = Vector3.ONE * randf_range(0.35, 0.70)
		muzzle.position = -current_weapon().muzzle_position
		
		raycast.force_raycast_update()
		
		# hitreg
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			
			# Hitting an enemy
			if collider.has_method("damage"):
				var killed = collider.damage(current_weapon().damage)
				ui.trigger_hitmarker(killed)
			
			# Creating an impact animation
			var impact = preload("res://src/scenes/impact.tscn")
			var impact_instance = impact.instantiate()
			impact_instance.play("shot")
			
			# TODO: add singleton World for a method to add effects like this
			# to the world into a specific node, instead of polluting the tree
			# root
			Utils.root().add_child(impact_instance)
			
			impact_instance.position = raycast.get_collision_point()
			impact_instance.look_at(camera.global_transform.origin, Vector3.UP, true)
			impact_instance.rotation_degrees.z = randf_range(0, 90)


# Toggle between available weapons (listed in 'weapons')
func handle_action_weapon_toggle():
	if Input.is_action_just_pressed("weapon_toggle"):
		weapon_index = wrap(weapon_index + 1, 0, weapons.size())
		initiate_change_weapon(weapon_index)
		Audio.play_at("weapon_change.ogg")


# Initiates the weapon changing animation (tween)
func initiate_change_weapon(index):
	weapon_index = index
	var tween = self.create_tween()
	tween.tween_property(
		weapon_container, "position", WEAPON_CONTAINER_OFFSET - Vector3(0, 1, 0), 0.1
	)
	tween.tween_callback(change_weapon)  # Changes the model


# TASK: most of this settings could go in a separated script
# Switches the weapon model (off-screen)
func change_weapon():
	# Step 1. Remove previous weapon model(s) from weapon_container
	self.get_tree().call_group("weapon_model", "queue_free")
	
	# Step 2. Place new weapon model in weapon_container
	ui.switch_weapon(current_weapon())
	var weapon_model = current_weapon().model.instantiate()
	weapon_model.add_to_group("weapon_model")
	weapon_container.add_child(weapon_model)
	
	# Step 3. Reposition model
	weapon_model.position = current_weapon().model_offset
	weapon_model.rotation_degrees = Vector3(0, 180, 0)  # Model assets are upside down lol
	
	# Step 4. Set model to only render on layer 2 (the weapon camera)
	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2


func damage(amount: int):
	health -= amount
	ui.update_player_health(health)
	if health < 0:
		died.emit()


func current_weapon() -> Weapon:
	return weapons[weapon_index]


func current_weapon_timer() -> Timer:
	return weapon_timers[weapon_index]
