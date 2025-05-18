extends Control

@onready var toolbar_selection: TextureRect = $FixedHUD/ToolbarSelectionSquare

var f1_hide_hud := false:
	set(value):
		f1_hide_hud = value
		update_visibility()

var is_esc_menu_open := false:
	set(value):
		is_esc_menu_open = value
		update_visibility()

func update_visibility():
		$OptionsMenu.visible = is_esc_menu_open
		$UnpausedHUD.visible = not is_esc_menu_open and not f1_hide_hud
		$FixedHUD.visible = not f1_hide_hud
		if is_esc_menu_open:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what):
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		is_esc_menu_open = true

func _process(_delta):
	if Input.is_action_just_pressed("escape"):
		is_esc_menu_open = not is_esc_menu_open

func _on_resume_button_pressed():
	is_esc_menu_open = false

func _on_quit_button_pressed():
	SceneController.quit()

func update_selected_block(value: int):
	const TEXTURE_SIZE = 22
	const SQUARE_OVERFLOW = 2
	var selection_offset = ((TEXTURE_SIZE - SQUARE_OVERFLOW) * 4) * (value - 4)
	toolbar_selection.offset_left = selection_offset - TEXTURE_SIZE * 2.0
	toolbar_selection.offset_right = selection_offset + TEXTURE_SIZE * 2.0
