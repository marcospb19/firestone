extends Control

@onready var unpaused_hud: Control = $UnpausedHUD
@onready var toolbar_selection: TextureRect = $FixedHUD/ToolbarSelectionSquare
@onready var options_menu: Control = $OptionsMenu

var is_menu_open := false:
	set(value):
		is_menu_open = value
		options_menu.visible = value
		unpaused_hud.visible = not value
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
	const TEXTURE_SIZE = 22
	const SQUARE_OVERFLOW = 2
	var selection_offset = ((TEXTURE_SIZE - SQUARE_OVERFLOW) * 4) * (value - 4)
	toolbar_selection.offset_left = selection_offset - TEXTURE_SIZE * 2.0
	toolbar_selection.offset_right = selection_offset + TEXTURE_SIZE * 2.0
