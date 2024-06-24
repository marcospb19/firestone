extends Node

const MAIN_SCENE_GROUP := "main_scene"

enum MainScene {
	MAIN_MENU,
	LEVEL_DEMO,
	LEVEL_TRAIN,
}

const SCENE_PATHS := {
	MainScene.MAIN_MENU: "res://src/scenes/ui/main_menu.tscn",
	MainScene.LEVEL_DEMO: "res://src/scenes/levels/demo_level.tscn",
	MainScene.LEVEL_TRAIN: "res://src/scenes/levels/train_level.tscn",
}

var last_loaded_scene: MainScene


func _ready():
	for scene in SCENE_PATHS:
		var path = SCENE_PATHS[scene]
		assert(ResourceLoader.exists(path), "scene path doesn't exist: '%s'" % path)


func load_and_set_scene(scene: MainScene):
	self.get_tree().call_group(MAIN_SCENE_GROUP, "queue_free")
	var node: Node = load(SCENE_PATHS[scene]).instantiate()
	node.add_to_group(MAIN_SCENE_GROUP)
	self.get_tree().root.add_child(node)
	last_loaded_scene = scene


func go_to_main_menu():
	load_and_set_scene(MainScene.MAIN_MENU)


func reload_current_scene():
	load_and_set_scene(last_loaded_scene)


func quit():
	self.get_tree().quit()
