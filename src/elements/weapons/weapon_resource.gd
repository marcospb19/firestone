class_name Weapon

extends Resource

@export_subgroup("Model")
@export var model: PackedScene  ## Model of the weapon
@export var model_offset: Vector3  ## On-screen position
@export var muzzle_position: Vector3  ## On-screen position of muzzle flash

@export_subgroup("Stats")
@export var firerate: float = 60.0  ## In RPM
@export var damage: float
# TASK: reimplement shotguns
# @export_range(1, 5) var shot_count: int = 1  ## Amount of shots

@export_subgroup("Sounds")
@export var fire_sound: Resource
@export_range(-30, 30) var volume_adjust: int

@export_subgroup("Crosshair")
@export var crosshair_texture: Texture2D


func firerate_cooldown():
	return 1.0 / (firerate / 60.0)
