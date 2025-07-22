# =============================================================================
# scene_loader.gd - A Safe Scene Transition Manager
# =============================================================================
#
# WHAT IT IS:
# A very simple but critical Autoload Singleton. Its ONLY job is to handle
# changing or reloading scenes.
#
# ARCHITECTURE:
# The core problem it solves is "dangling references". When you change a scene,
# old nodes are destroyed, but global singletons (like GameManager) might still
# hold references to them, which causes crashes. This loader ensures that we
# always clean up those old references BEFORE the scene change happens.
#
# All other scripts in the game should use `SceneLoader.change_scene()` instead
# of calling `get_tree().change_scene_to_file()` directly.
#
# =============================================================================
extends Node


const MAIN_GAME_SCENE = "res://src/main.tscn"

## This is now the one and only safe way to change to a new scene.
func change_scene(scene_path: String):
	MenuManager.clear_history()
	var level_container = get_tree().current_scene.get_node_or_null("LevelContainer")
	
	if level_container:
		for child in level_container.get_children():
			child.queue_free()
		
		var scene = await load(scene_path).instantiate()
		level_container.add_child(scene)
	
	GameManager.resume()

## This is the one and only safe way to reload the current scene.
func reload_current_scene():
	MenuManager.clear_history()
	print("SceneLoader: Reloading current scene.")
	
	GameManager.prepare_for_scene_change()
	get_tree().reload_current_scene()
	GameManager.resume()
