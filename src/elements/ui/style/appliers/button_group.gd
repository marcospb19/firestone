extends HFlowContainer

@onready var normal_style: StyleBoxFlat = preload("res://src/elements/ui/style/button_normal_style.tres")
@onready var hover_style: StyleBoxFlat = preload("res://src/elements/ui/style/button_hover_style.tres")


func _ready():
	self.add_theme_constant_override("v_separation", 10)
	
	for button in self.find_children("*", "Button"):
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
