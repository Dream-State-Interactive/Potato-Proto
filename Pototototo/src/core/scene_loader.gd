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

## This is now the one and only safe way to change to a new scene.
func change_scene(scene_path: String):
	print("SceneLoader: Changing to scene '", scene_path, "'")
	
	# We call our custom cleanup function in the GameManager.
	# This clears out hud_instance, player_instance, etc., preventing crashes.
	GameManager.prepare_for_scene_change()
	
	# Now that references are cleared, it's safe to change the scene.
	get_tree().change_scene_to_file(scene_path)

## This is the one and only safe way to reload the current scene.
func reload_current_scene():
	print("SceneLoader: Reloading current scene.")
	
	GameManager.prepare_for_scene_change()
	get_tree().reload_current_scene()
