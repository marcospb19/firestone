extends Node3D

@onready var player = $Player


func _process(_delta):
	if Input.is_action_just_pressed("reset"):
		SceneController.switch_to(SceneController.MainScene.LEVEL_DEMO)


func _on_player_died():
	# BUG: dying closes the options menu
	SceneController.switch_to(SceneController.MainScene.LEVEL_DEMO)
