# BUG: weapon sway when moving on floor goes into weird directions
# TODO: remove camera lerp curves

extends CharacterBody3D

signal health_updated

@export_subgroup("Properties")
@export var movement_speed = 5
@export var jump_strength = 4
@export var jet_strength = 23
@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []
@export var crosshair: TextureRect

var weapon_index := 0
# TASK: put this in a singleton
var mouse_captured := true
var mouse_sensitivity := 0.00082
var gamepad_sensitivity := 0.075
var health := 100
# TODO: remove this, self.velocity is enough
var gravity := 0.0
var previously_floored := false
var jump := true
var container_offset := Vector3(1.2, -1.1, -2.75)
var movement_velocity: Vector3
var weapon: Weapon
var tween: Tween

@onready var camera := $Head/Camera
@onready var raycast := $Head/Camera/RayCast
@onready var muzzle := $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Muzzle
@onready var container := $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Container
@onready var sound_footsteps := $SoundFootsteps
@onready var blaster_cooldown := $Cooldown


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	weapon = weapons[weapon_index]  # Weapon must never be null
	initiate_change_weapon(weapon_index)


# Rotates player look, input is X and Y diff
func apply_rotation(diff: Vector2):
	# Horizontal movement
	rotation.y -= diff.x
	# Vertical movement
	camera.rotation.x -= diff.y


func _physics_process(delta):
	# Handle functions
	handle_controls(delta)
	
	# apply gravity
	gravity += 20 * delta
	
	# Movement
	var applied_velocity: Vector3
	movement_velocity = transform.basis * movement_velocity  # Move forward
	
	applied_velocity = velocity.lerp(movement_velocity, delta * 10)
	applied_velocity.y = -gravity
	
	velocity = applied_velocity
	self.move_and_slide()
	
	container.position = lerp(
		container.position, container_offset - (applied_velocity / 30), delta * 10
	)
	
	# Movement sound
	sound_footsteps.stream_paused = true
	
	if self.is_on_floor():
		if abs(velocity.x) > 1 or abs(velocity.z) > 1:
			sound_footsteps.stream_paused = false
	
	#Landing after jump or falling
	camera.position.y = lerp(camera.position.y, 0.0, delta * 5)
	
	if self.is_on_floor() and gravity > 1 and !previously_floored:  # Landed
		Audio.play_at("land.ogg")
		camera.position.y = -0.1
	
	previously_floored = self.is_on_floor()
	
	# Falling/respawning
	if position.y < -10:
		self.get_tree().reload_current_scene()


func _input(event):
	# Mouse look control
	if event is InputEventMouseMotion and mouse_captured:
		var mouse_rotation = event.relative * mouse_sensitivity
		apply_rotation(mouse_rotation)


func handle_controls(delta: float):
	handle_action_shoot()
	handle_action_weapon_toggle()
	handle_action_jump_and_jet(delta)
	
	# Mouse capture
	if Input.is_action_just_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	
	if Input.is_action_just_pressed("mouse_capture_exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
	
	# Movement
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	movement_velocity = Vector3(input.x, 0, input.y).normalized() * movement_speed
	
	# Gamepad look control
	var gamepad_rotation_input := Input.get_vector(
		"look_right", "look_left", "look_down", "look_up"
	)
	var gamepad_rotation = gamepad_rotation_input.limit_length(1.0) * gamepad_sensitivity
	apply_rotation(gamepad_rotation)
	
	# Jumping
	if Input.is_action_just_pressed("jump"):
		if jump:
			Audio.play_at(["jump_a.ogg", "jump_b.ogg", "jump_c.ogg"])
			gravity = -jump_strength
			jump = false


func handle_action_jump_and_jet(delta: float):
	# BUG: velocity still accumulates for ceiling collisions, this only checks floors
	if self.is_on_floor():
		gravity = 0.0
	
	if Input.is_action_pressed("jump"):
		if self.is_on_floor():
			gravity = -jump_strength
		gravity -= jet_strength * delta


func handle_action_shoot():
	if Input.is_action_pressed("shoot") and blaster_cooldown.is_stopped():
		Audio.play(weapon.sound_shoot)
		
		# Reset muzzle animation
		muzzle.play()
		muzzle.rotation_degrees.z = randf_range(-45, 45)
		muzzle.scale = Vector3.ONE * randf_range(0.40, 0.75)
		# BUG: when the weapon sways on screen, muzzle effect doesn't follow
		# this is incorrerent cause when played moves sideways it follows, and
		# this it's not explained by acceleration changes, disrespecting inertia
		muzzle.position = container.position - weapon.muzzle_position
		
		blaster_cooldown.start(weapon.cooldown)
		
		# Shoot the weapon, amount based on shot count
		for n in weapon.shot_count:
			# BUG: I can hit enemies through walls
			raycast.force_raycast_update()
			
			if !raycast.is_colliding():
				continue  # Don't create impact when raycast didn't hit
			
			var collider = raycast.get_collider()
			
			# Hitting an enemy
			if collider.has_method("damage"):
				collider.damage(weapon.damage)
			
			# Creating an impact animation
			var impact = preload("res://src/objects/impact.tscn")
			var impact_instance = impact.instantiate()
			impact_instance.play("shot")
			
			self.get_tree().root.add_child(impact_instance)
			
			impact_instance.position = (
				raycast.get_collision_point() + (raycast.get_collision_normal() / 10)
			)
			impact_instance.look_at(camera.global_transform.origin, Vector3.UP, true)


# Toggle between available weapons (listed in 'weapons')
func handle_action_weapon_toggle():
	if Input.is_action_just_pressed("weapon_toggle"):
		weapon_index = wrap(weapon_index + 1, 0, weapons.size())
		initiate_change_weapon(weapon_index)
		
		Audio.play_at("weapon_change.ogg")


# Initiates the weapon changing animation (tween)
func initiate_change_weapon(index):
	weapon_index = index
	tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT_IN)
	tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), 0.1)
	tween.tween_callback(change_weapon)  # Changes the model


# Switches the weapon model (off-screen)
func change_weapon():
	weapon = weapons[weapon_index]
	
	# Step 1. Remove previous weapon model(s) from container
	for n in container.get_children():
		container.remove_child(n)
	
	# Step 2. Place new weapon model in container
	var weapon_model = weapon.model.instantiate()
	container.add_child(weapon_model)
	
	weapon_model.position = weapon.position
	weapon_model.rotation_degrees = weapon.rotation
	
	# Step 3. Set model to only render on layer 2 (the weapon camera)
	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2
		
	# Set weapon data
	raycast.target_position = Vector3(0, 0, -10000000)
	crosshair.texture = weapon.crosshair


func damage(amount):
	health -= amount
	health_updated.emit(health)  # Update health on HUD
	if health < 0:
		get_tree().reload_current_scene()  # Reset game when out of health
