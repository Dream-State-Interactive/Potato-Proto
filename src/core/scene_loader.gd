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
var current_scene_path: String = ""

## This is now the one and only safe way to change to a new scene.
func change_scene(scene_path: String):
	if scene_path.is_empty():
		printerr("SceneLoader: change_scene was called with an empty path! Aborting scene change.")
		return
	
	GameManager.prepare_for_scene_change()
	GameManager.current_level_path = scene_path
	current_scene_path = scene_path
	MenuManager.clear_history()
	
	get_tree().change_scene_to_file(scene_path)
	GameManager.on_level_loaded()
	
	GameManager.resume()

## Restarts the current level
func reload_current_scene():
	if current_scene_path.is_empty():
		printerr("SceneLoader: Cannot restart level, no level path is stored.")
		return
		
	print("Restarting level: ", current_scene_path)
	GameManager.reset_game_state()
	change_scene(current_scene_path)

## Restarts the Main scene itself
func hard_reset_game():
	MenuManager.clear_history()
	print("SceneLoader: Reloading current scene.")
	GameManager.prepare_for_scene_change()
	get_tree().reload_current_scene()
	GameManager.resume()
