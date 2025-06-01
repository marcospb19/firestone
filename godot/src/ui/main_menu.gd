extends Control

func _ready():
	# A corner case, as this is the project entry point, it needs call this to
	# be cleanable later, it's a detail of how SceneController works
	self.add_to_group(SceneController.MAIN_SCENE_GROUP_NAME)

# func _on_button_pressed():
# 	SceneController.switch_to(SceneController.MainScene.VARIANT)

func _on_quit_button_pressed():
	SceneController.quit()
