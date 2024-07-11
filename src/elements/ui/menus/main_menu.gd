extends Control


func _ready() -> void:
	# A corner case, as this is the project entry point, it needs call this to
	# be cleanable later, it's a detail of how SceneController works
	self.add_to_group(SceneController.MAIN_SCENE_GROUP_NAME)


func _on_containers_button_pressed():
	SceneController.switch_to(SceneController.MainScene.CONTAINERS_LEVEL)


func _on_platforms_button_pressed():
	SceneController.switch_to(SceneController.MainScene.PLATFORMS_LEVEL)


func _on_quit_button_pressed():
	SceneController.quit()
