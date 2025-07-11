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
	# Close any open overlay menus immediately
	MenuManager.hide_all_menus()
	print("SceneLoader: Request to change scene to '", scene_path, "'")
	
	# Check if the destination is a "level" scene.
	# (Can also do something like check for a specific group or class name)
	if scene_path.begins_with("res://src/levels/"):
		# The destination is a level, so we need to go through our persistent Main scene.
		print("Destination is a level. Loading via Main.tscn...")
		GameManager.start_new_game_at_level(scene_path)
	else:
		# The destination is a simple menu (like Settings or back to MainMenu).
		# So just change back to menu directly.
		print("Destination is a menu. Performing simple scene change...")
		GameManager.prepare_for_scene_change() # Still important to clear old references
		get_tree().change_scene_to_file(scene_path)
	# ----------------------------------------

## This is the one and only safe way to reload the current scene.
func reload_current_scene():
	MenuManager.hide_all_menus()
	print("SceneLoader: Reloading current scene.")
	
	GameManager.prepare_for_scene_change()
	get_tree().reload_current_scene()
