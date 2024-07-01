extends Control

@onready var health: Label = $Health
@onready var crosshair: TextureRect = $Crosshair
@onready var hitmarker: TextureRect = $Hitmarker

var hitmarker_tween: Tween


func update_health(value: int):
	health.text = str(value) + "%"


func switch_weapon(weapon: Weapon):
	crosshair.texture = weapon.crosshair_texture


func trigger_hitmarker(hit_killed: bool):
	var s = hitmarker_tween_settings(hit_killed)
	
	hitmarker.texture = s.texture
	hitmarker.scale = Vector2.ONE * s.marker_scale
	
	# Clear last tween
	if hitmarker_tween is Tween:
		hitmarker_tween.kill()
	
	# Set new tween
	hitmarker_tween = self.create_tween()
	hitmarker_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	hitmarker_tween.tween_method(hitmarker.set_modulate, s.from, s.to, s.duration)
	
	if s.hold_black_effect:
		hitmarker_tween.chain().tween_method(
			hitmarker.set_modulate, s.to, Color.BLACK * Color.TRANSPARENT, 0.5
		)


func hitmarker_tween_settings(killed: bool) -> Dictionary:
	if killed:
		return {
			"from": Color.RED * 17,
			"texture": load("res://assets/sprites/double_hitmarker.png"),
			"duration": 2.5,
			"marker_scale": 0.7,
			"to": Color.BLACK * 0.8 + Color.TRANSPARENT * 0.2,
			"hold_black_effect": true,
		}
	else:
		return {
			"from": Color.WHITE * 10,
			"texture": load("res://assets/sprites/single_hitmarker.png"),
			"duration": 1.0,
			"marker_scale": 0.55,
			"to": Color.TRANSPARENT,
			"hold_black_effect": false,
		}
