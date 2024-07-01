extends ProgressBar


func _ready():
	update_health(100)


func update_health(health: int):
	value = health
	__update_color()


func __update_color():
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = __get_color_for_health()
	self.add_theme_stylebox_override("fill", bar_style)


func __get_color_for_health() -> Color:
	if value > 50.0:
		# Green to orange
		return lerp(Color.ORANGE, Color.LAWN_GREEN, (self.value - 50.0) / 50.0)
	else:
		# Orange to red
		return lerp(Color.RED, Color.ORANGE, self.value / 50.0)
