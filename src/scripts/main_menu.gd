extends Control


func _ready() -> void:
	# A corner case, as this is the project entry point, it needs call this to
	# be cleanable later, it's a detail of how SceneController works
	self.add_to_group(SceneController.MAIN_SCENE_GROUP)


func _on_train_level_button_pressed() -> void:
	SceneController.load_and_set_scene(SceneController.MainScene.LEVEL_TRAIN)


func _on_demo_level_button_pressed() -> void:
	SceneController.load_and_set_scene(SceneController.MainScene.LEVEL_DEMO)


func _on_exit_button_pressed() -> void:
	SceneController.quit()
