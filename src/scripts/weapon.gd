class_name Weapon

extends Resource

@export_subgroup("Model")
@export var model: PackedScene  ## Model of the weapon
@export var position: Vector3  ## On-screen position
@export var rotation: Vector3  ## On-screen rotation
@export var muzzle_position: Vector3  ## On-screen position of muzzle flash

@export_subgroup("Stats")
@export_range(0.01, 1) var cooldown: float = 0.1  ## Firerate
@export_range(0, 100) var damage: float  ## Damage per hit
# TASK: reimplement ashotguns
# @export_range(1, 5) var shot_count: int = 1  ## Amount of shots

@export_subgroup("Sounds")
@export var sound_shoot: Resource  ## Audio to play
@export_range(-30, 30) var volume_db: int  ## Volume adjustment

@export_subgroup("Crosshair")
@export var crosshair: Texture2D  ## Image of crosshair on-screen
