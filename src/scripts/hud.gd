extends CanvasLayer

@onready var health = $Health
@onready var crosshair = $Crosshair
@onready var hitmarker = $Hitmarker

var tween: Tween

func _on_health_updated(value: int):
	health.text = str(value) + "%"


func _on_player_weapon_switched(weapon: Weapon):
	crosshair.texture = weapon.crosshair_texture


func _on_player_hit_enemy(killed: bool):
	var s = hitmarker_tween_settings(killed)
	
	hitmarker.texture = s.texture
	hitmarker.scale = Vector2.ONE * s.marker_scale
	
	# Clear last tween
	if tween is Tween:
		tween.kill()
	
	# Set new tween
	tween = self.create_tween()
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_method(hitmarker.set_modulate, s.from, s.to, s.duration)
	
	if s.hold_black_effect:
		tween.chain().tween_method(
			hitmarker.set_modulate, s.to, Color.BLACK * Color.TRANSPARENT, 0.5
		)


func hitmarker_tween_settings(killed: bool) -> Dictionary:
	if killed:
		return {
			"from": Color.RED * 17,
			"texture": load("res://assets/sprites/double-hitmarker.png"),
			"duration": 2.5,
			"marker_scale": 0.7,
			"to": Color.BLACK * 0.8 + Color.TRANSPARENT * 0.2,
			"hold_black_effect": true,
		}
	else:
		return {
			"from": Color.WHITE * 10,
			"texture": load("res://assets/sprites/single-hitmarker.png"),
			"duration": 1.0,
			"marker_scale": 0.55,
			"to": Color.TRANSPARENT,
			"hold_black_effect": false,
		}
