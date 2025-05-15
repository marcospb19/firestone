extends Node

enum MainScene {
	# VARIANT,
}

const SCENE_PATHS := {
	# MainScene.VARIANT: "res://...",
}

var last_loaded_scene_path: String

func _ready():
	for scene in SCENE_PATHS:
		var path = SCENE_PATHS[scene]
		assert(ResourceLoader.exists(path), "scene path doesn't exist: '%s'" % path)

func switch_to(scene: MainScene):
	var path = SCENE_PATHS[scene]
	__switch_to_scene_at(path)
	last_loaded_scene_path = path

func reload_current_scene():
	__switch_to_scene_at(last_loaded_scene_path)

func __switch_to_scene_at(path: String):
	self.get_tree().call_group("scene_controller_clear", "queue_free")
	var node: Node = load(path).instantiate()
	node.add_to_group("scene_controller_clear")
	self.get_tree().root.add_child(node)

func quit():
	self.get_tree().quit()
