extends CanvasLayer


func _on_health_updated(health):
	$Health.text = str(health) + "%"


func _on_player_weapon_switched(weapon: Weapon):
	$Crosshair.texture = weapon.crosshair
