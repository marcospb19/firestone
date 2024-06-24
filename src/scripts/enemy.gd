extends Node3D

@export var player: Node3D

var health := 100.0
var time := 0.0
# TASK: use naming conventions for all bools in project
var already_dead := false

@onready var raycast: RayCast3D = $RayCast
@onready var muzzle_a: AnimatedSprite3D = $MuzzleA
@onready var muzzle_b: AnimatedSprite3D = $MuzzleB


func _process(delta: float):
	self.look_at(player.global_position + Vector3.UP * 0.5, Vector3.UP, true)  # Look at player
	position.y += cos(time * 5) * delta  # Up and down swing
	time += delta


## Take damage from another source
## @return: did this damage kill?
func damage(amount: int) -> bool:
	Audio.play_at("enemy_hurt.ogg")
	health -= amount
	
	if health > 0 or already_dead:
		return false
	
	Audio.play_at("enemy_destroy.ogg")
	already_dead = true
	self.queue_free()
	return true


# Shoot when timer hits 0
func _on_timer_timeout():
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# Raycast collides with player
		if collider.has_method("damage"):
			collider.damage(5)  # Apply damage to player
			
			# Play muzzle flash animation(s)
			muzzle_a.play()
			muzzle_a.rotation_degrees.z = randf_range(0, 90)
			muzzle_b.play()
			muzzle_b.rotation_degrees.z = randf_range(0, 90)
			
			Audio.play_at("enemy_attack.ogg")
