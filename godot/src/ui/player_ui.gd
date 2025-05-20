extends Control

@onready var hotbar_selection_rect: TextureRect = $Hotbar/SelectionRect
@onready var hotbar_previews_container: Control = $Hotbar/PreviewsContainer
const BLOCK_PREVIEW_RENDERER := preload("res://src/scenes/block_preview_renderer.tscn")
const ICON_SCALE := 4.0
const HOTBAR_SELECTION_TEXTURE_SIZE = 22

var f1_hide_hud := false:
	set(value):
		f1_hide_hud = value
		update_visibility()

var is_esc_menu_open := false:
	set(value):
		is_esc_menu_open = value
		update_visibility()

func _ready():
	update_selected_block(0)
	set_hotbar_preview(VoxelWorld.FaceKind.AND_BLANK, 0)

func update_visibility():
	$OptionsMenu.visible = is_esc_menu_open
	$Crosshair.visible = not is_esc_menu_open and not f1_hide_hud
	$Hotbar.visible = not f1_hide_hud
	if is_esc_menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what):
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		is_esc_menu_open = true

func _process(_delta):
	if Input.is_action_just_pressed("esc"):
		is_esc_menu_open = not is_esc_menu_open

func _on_resume_button_pressed():
	is_esc_menu_open = false

func _on_quit_button_pressed():
	SceneController.quit()

func update_selected_block(index: int):
	var x_hotbar_offset = get_element_offset(index)
	hotbar_selection_rect.offset_left = x_hotbar_offset - HOTBAR_SELECTION_TEXTURE_SIZE * ICON_SCALE / 2.0
	hotbar_selection_rect.offset_right = x_hotbar_offset + HOTBAR_SELECTION_TEXTURE_SIZE * ICON_SCALE / 2.0

func update_hotbar_preview(index: int, face_kind: VoxelWorld.FaceKind):
	set_hotbar_preview(face_kind, index)

func get_element_offset(index: int) -> float:
	const SQUARE_OVERFLOW = 2
	return ((HOTBAR_SELECTION_TEXTURE_SIZE - SQUARE_OVERFLOW) * ICON_SCALE) * (index - 4)

func set_hotbar_preview(face_kind: VoxelWorld.FaceKind, index: int):
	var rect := TextureRect.new()
	hotbar_previews_container.add_child(rect)

	var preview_viewport: SubViewport = BLOCK_PREVIEW_RENDERER.instantiate()
	rect.add_child(preview_viewport)
	preview_viewport.setup_block_and_camera(face_kind)

	var x_hotbar_offset = get_element_offset(index)
	rect.anchor_left = 0.5
	rect.anchor_right = 0.5
	var preview_size = preview_viewport.size.x
	rect.offset_left = x_hotbar_offset - preview_size / 2.0
	rect.offset_top -= 9
	rect.offset_right = x_hotbar_offset + preview_size / 2.0
	call_deferred('__update_preview_rect_texture', rect, preview_viewport)

# Wait for it to render, then get rid of the viewport
func __update_preview_rect_texture(rect: TextureRect, viewport: SubViewport):
	# Skip two frames to guarantee our the texture image will be available
	await self.get_tree().process_frame
	await self.get_tree().process_frame
	rect.texture = ImageTexture.create_from_image(viewport.get_texture().get_image())
	rect.remove_child(viewport)
	viewport.queue_free()
