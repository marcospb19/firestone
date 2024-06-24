extends CanvasLayer

@onready var options_menu: Control = $OptionsMenu
@onready var gameplay_hud: Control = $GameplayHUD

var is_menu_open := false:
	set(value):
		is_menu_open = value
		update_state()


func _notification(what):
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		is_menu_open = true


func _process(_delta):
	if Input.is_action_just_pressed("escape"):
		is_menu_open = not is_menu_open


func update_state():
	options_menu.visible = is_menu_open
	gameplay_hud.visible = not is_menu_open
	
	if is_menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Utils.set_low_fps_cap()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Utils.set_high_fps_cap()


func _on_options_menu_menu_closed():
	is_menu_open = false


func update_player_health(health: int):
	gameplay_hud.update_health(health)


func trigger_hitmarker(hit_killed: bool):
	gameplay_hud.trigger_hitmarker(hit_killed)


func switch_weapon(weapon: Weapon):
	gameplay_hud.switch_weapon(weapon)
