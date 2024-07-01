extends Control

signal menu_closed


func _on_resume_button_pressed():
	menu_closed.emit()


func _on_main_menu_button_pressed():
	SceneController.go_to_main_menu()
