extends CanvasLayer

@onready var options_menu: Control = $OptionsMenu
@onready var gameplay_hud: Control = $GameplayHUD

# func _notification(what):
#	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:

# func _process(_delta):
# 	if Input.is_action_just_pressed("escape"):
# 		is_menu_open = not is_menu_open

# func update_state():
# 	if is_menu_open:
# 		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
# 	else:
# 		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
