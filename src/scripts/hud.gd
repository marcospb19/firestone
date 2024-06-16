extends CanvasLayer

@onready var health = $Health
@onready var crosshair = $Crosshair
@onready var hitmarker = $Hitmarker


func _on_health_updated(value: int):
	health.text = str(value) + "%"


func _on_player_weapon_switched(weapon: Weapon):
	crosshair.texture = weapon.crosshair


func _on_player_hit_enemy(killed: bool):
	var from: Color
	var to: Color
	var texture: Texture
	var duration: float
	var marker_scale: float
	if killed:
		from = Color.RED * 4
		texture = load("res://assets/sprites/double-hitmarker.png")
		duration = 3.0
		marker_scale = 0.65
		to = from * Color.TRANSPARENT * Color.AQUA
	else:
		from = Color.WHITE * 6.0
		texture = load("res://assets/sprites/single-hitmarker.png")
		duration = 1.0
		marker_scale = 0.45
		to = from * Color.TRANSPARENT
	
	hitmarker.texture = texture
	hitmarker.scale = Vector2.ONE * marker_scale
	
	self.create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).tween_method(
		hitmarker.set_modulate, from, to, duration
	)
