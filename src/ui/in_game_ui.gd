extends CanvasLayer

@onready var gameplay_hud: Control = $GameplayHUD
@onready var toolbar_selection: CanvasLayer = $GameplayHUD/ToolbarSelection
@onready var options_menu: Control = $OptionsMenu

var is_menu_open := false:
	set(value):
		is_menu_open = value
		options_menu.visible = value
		gameplay_hud.visible = not value
		if is_menu_open:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what):
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		is_menu_open = true

func _process(_delta):
	if Input.is_action_just_pressed("escape"):
		is_menu_open = not is_menu_open

func _on_resume_button_pressed():
	is_menu_open = false

func _on_quit_button_pressed():
	SceneController.quit()

func update_selected_block(value: int):
	var scaled_size = 20 * 4
	toolbar_selection.offset = Vector2(scaled_size, 0) * (value - 4.0)
