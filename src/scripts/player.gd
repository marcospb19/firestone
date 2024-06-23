extends CharacterBody3D

# TODO: add bullet tracers
# TODO: re-add weapon model kickback
# TODO: make camera vertical swing respect inertia

signal health_updated(int)
signal weapon_switched(Weapon)
signal hit_enemy(bool)

@export_subgroup("Properties")
@export var movement_speed = 5
@export var jump_strength = 4
@export var jet_strength = 23
@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []

var mouse_sensitivity := 0.0008
var gamepad_sensitivity := 0.075
var health := 100
var movement_velocity: Vector3
var previously_floored := false
var jump := true
var weapon_container_offset := Vector3(1.2, -1.1, -2.75)
var weapon: Weapon
var weapon_index := 0

@onready var camera: Camera3D = $Head/Camera
@onready var raycast: RayCast3D = $Head/Camera/RayCast
@onready var weapon_container: Node3D = $Head/Camera/ViewportContainer/WeaponView/CameraItem/WeaponContainer
@onready var muzzle: AnimatedSprite3D = $Head/Camera/ViewportContainer/WeaponView/CameraItem/WeaponContainer/Muzzle
@onready var sound_footsteps: AudioStreamPlayer = $SoundFootsteps
@onready var blaster_cooldown: Timer = $Cooldown


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	weapon = weapons[weapon_index]  # Weapon must never be null
	initiate_change_weapon(weapon_index)


# Rotates player look, input is X and Y diff
func apply_rotation(diff: Vector2):
	# Horizontal rotation
	rotation.y -= diff.x
	# Vertical rotation
	camera.rotation.x = clampf(camera.rotation.x - diff.y, deg_to_rad(-90.0), deg_to_rad(90.0))


func _physics_process(delta: float):
	# apply gravity
	velocity.y -= 20 * delta
	
	# Handle functions
	handle_controls(delta)
	
	weapon_container.position = lerp(
		weapon_container.position, weapon_container_offset - (velocity / 30), delta * 10
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
	
	# Falling/respawning
	if position.y < -10:
		self.get_tree().reload_current_scene()


func _input(event):
	# Mouse look control
	if event is InputEventMouseMotion and InputExt.is_mouse_captured():
		var mouse_rotation = event.relative * mouse_sensitivity
		apply_rotation(mouse_rotation)


func handle_controls(delta: float):
	handle_action_shoot()
	handle_action_weapon_toggle()
	handle_action_jump_and_jet(delta)
	
	# Movement
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement = Vector3(input.x, 0, input.y).limit_length(1.0) * movement_speed
	movement.y = velocity.y
	velocity = transform.basis * movement
	
	self.move_and_slide()
	
	# Gamepad look control
	var gamepad_rotation_input := Input.get_vector(
		"look_right", "look_left", "look_down", "look_up"
	)
	var gamepad_rotation = gamepad_rotation_input.limit_length(1.0) * gamepad_sensitivity
	apply_rotation(gamepad_rotation)
	
	# Jumping
	if Input.is_action_just_pressed("jump"):
		if jump:
			Audio.play_at_one_of(["jump_a.ogg", "jump_b.ogg", "jump_c.ogg"])
			velocity.y = -jump_strength
			jump = false


func handle_action_jump_and_jet(delta: float):
	if self.is_on_floor():
		velocity.y = 0.0
	
	if Input.is_action_pressed("jump"):
		if self.is_on_floor():
			velocity.y = max(jump_strength, velocity.y + jump_strength / 2.0)
		velocity.y += jet_strength * delta


func handle_action_shoot():
	if Input.is_action_pressed("shoot") and blaster_cooldown.is_stopped():
		blaster_cooldown.start(weapon.firerate_cooldown())
		Audio.play(weapon.fire_sound, weapon.volume_adjust)
		
		# Reset muzzle animation
		muzzle.play()
		muzzle.rotation_degrees.z = randf_range(0, 90)
		muzzle.scale = Vector3.ONE * randf_range(0.35, 0.70)
		muzzle.position = -weapon.muzzle_position
		
		raycast.force_raycast_update()
		
		# hitreg
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			
			# Hitting an enemy
			if collider.has_method("damage"):
				var killed = collider.damage(weapon.damage)
				hit_enemy.emit(killed)
			
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
		weapon_container, "position", weapon_container_offset - Vector3(0, 1, 0), 0.1
	)
	tween.tween_callback(change_weapon)  # Changes the model


# TASK: most of this settings could go in a separated script
# Switches the weapon model (off-screen)
func change_weapon():
	# Step 1. Remove previous weapon model(s) from weapon_container
	self.get_tree().call_group("weapon_model", "queue_free")
	
	# Step 2. Place new weapon model in weapon_container
	weapon = weapons[weapon_index]
	weapon_switched.emit(weapon)
	var weapon_model = weapon.model.instantiate()
	weapon_container.add_child(weapon_model)
	weapon_model.add_to_group("weapon_model")
	weapon_model.position = weapon.position
	# Weapon assets are upside down for some reason so rotate em
	weapon_model.rotation_degrees = Vector3(0, 180, 0)
	
	# Step 3. Set model to only render on layer 2 (the weapon camera)
	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2
	
	# Set weapon data
	raycast.target_position = Vector3(0, 0, -10000)


func damage(amount: int):
	health -= amount
	health_updated.emit(health)  # Update health on HUD
	if health < 0:
		get_tree().reload_current_scene()  # Reset game when out of health
